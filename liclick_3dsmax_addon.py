
"""

LiClick 批量图生3D —— 3ds Max 插件（Python + Qt）

"""

from __future__ import absolute_import, division, print_function, unicode_literals

import os

import re

import json

import time

import threading

import tempfile

try:
    import urllib.request as _urlreq
except ImportError:
    import urllib2 as _urlreq
import io
import contextlib

import subprocess

# pathlib 不用了，改用 os.listdir 以兼容 Python 2.7

from collections import defaultdict

# ── Qt 兼容导入（Max 2024- 用 PySide2，2025+ 用 PySide6）──────────────────────

try:

    from PySide2 import QtWidgets, QtCore, QtGui

    from PySide2.QtCore import Signal

except ImportError:

    from PySide6 import QtWidgets, QtCore, QtGui

    from PySide6.QtCore import Signal

# ── 3ds Max API ──────────────────────────────────────────────────────────────

from pymxs import runtime as rt


# ── Python 2.7 / 3.x 兼容垫片（让插件在 Max 2018/2020 的 Python 2.7 下也能运行）──
_CREATE_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0x08000000)
try:
    _DEVNULL = subprocess.DEVNULL
except AttributeError:
    _DEVNULL = open(os.devnull, "r+b")


def _makedirs(p):
    if p and not os.path.isdir(p):
        try:
            os.makedirs(p)
        except OSError:
            pass


import shutil


def _is_ascii_path(p):
    """路径是否纯 ASCII（含中文等非 ASCII 字符时返回 False）。"""
    try:
        p.encode("ascii")
        return True
    except Exception:
        return False


_ASCII_TMPDIR = None


def _ascii_tempdir():
    """返回纯 ASCII 的临时目录。中文用户名(如 C:\\Users\\张三\\...\\Temp)在 Py2.7/subprocess 下会按 ascii 编码而崩，这里规避。"""
    global _ASCII_TMPDIR
    if _ASCII_TMPDIR is not None:
        return _ASCII_TMPDIR
    d = tempfile.gettempdir()
    if _is_ascii_path(d):
        _ASCII_TMPDIR = d
        return d
    # Windows：用 8.3 短路径把中文目录名换成 ASCII
    if os.name == "nt":
        try:
            import ctypes
            try:
                du = d.decode("mbcs") if hasattr(d, "decode") else d
            except Exception:
                du = d
            buf = ctypes.create_unicode_buffer(600)
            if ctypes.windll.kernel32.GetShortPathNameW(du, buf, 600) and _is_ascii_path(buf.value):
                _ASCII_TMPDIR = buf.value
                return _ASCII_TMPDIR
        except Exception:
            pass
    # 兜底：在系统盘根目录建一个 ASCII 目录
    try:
        base = (os.environ.get("SystemDrive") or "C:") + os.sep + "liclick_tmp"
        if not os.path.isdir(base):
            os.makedirs(base)
        if _is_ascii_path(base):
            _ASCII_TMPDIR = base
            return base
    except Exception:
        pass
    _ASCII_TMPDIR = d
    return d


def _ascii_temp(ext):
    """生成纯英文(ASCII)临时文件路径，避免中文路径在 Python 2.7 / subprocess 下出错。"""
    uid = "{}_{}".format(os.getpid(), int(time.time() * 1000000.0) % 99999999)
    return os.path.join(_ascii_tempdir(), "liclick_up_" + uid + ext)


def _real_image_ext(path):
    """按文件头(magic bytes)判断真实图片格式，返回正确扩展名。"""
    try:
        with open(path, "rb") as f:
            head = f.read(12)
    except Exception:
        return None
    if head[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if head[:2] == b"BM":
        return ".bmp"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return ".gif"
    if head[:2] in (b"II", b"MM"):
        return ".tif"
    return None


def _ascii_image_copy(src):
    """把贴图复制成『纯英文路径 + 与真实内容匹配的扩展名』再交给 Max 加载。修两类坑：
    ① 中文/非 ASCII 路径在老版 Max 加载不了；
    ② Blender 导出的 .basecolor.png 实为 JPEG 内容(仅扩展名是 png)，老版 Max(2018~2022) 按扩展名当 PNG 解码→失败→灰模。"""
    real = _real_image_ext(src)
    ext = real or (os.path.splitext(src)[1].lower() or ".png")
    # 已是纯英文路径且扩展名与真实格式一致 → 不必复制
    if _is_ascii_path(src) and os.path.splitext(src)[1].lower() == ext:
        return src
    try:
        dst = _ascii_temp(ext)
        shutil.copy2(src, dst)
        return dst
    except Exception:
        return src


# ===== 自动更新：用户装好后自动从 Gitee 拉最新插件；作者每次只需 push 一份插件文件 =====
ADDON_VERSION = "2.0.0"   # 每次发布新版就改大（如 2.0.1 / 2.1.0），用户端据此判断是否更新
# 作者发布：建一个 Gitee 仓库，把本插件文件 push 上去，填下面两行即可启用自动更新。
# GITEE_USER 留空 = 不启用（用户端不会去联网检查）。
GITEE_USER = "foodliao"               # ← 你的 Gitee 用户名
GITEE_REPO = "max-toolbox"            # ← 你的 Gitee 仓库名
GITEE_BRANCH = "master"
_UPDATE_REMOTE_PY = "liclick_3dsmax_addon.py"   # 仓库里这份 Max 插件的文件名


def _update_base_url():
    if not GITEE_USER:
        return None
    return "https://foodliao.github.io/-/"   # 改为 GitHub Pages（全部托管在 GitHub 一个库）


def _parse_ver(s):
    try:
        nums = re.findall(r"\d+", s or "")
        return tuple(int(x) for x in nums[:4]) or (0,)
    except Exception:
        return (0,)


def _fetch_text(url, timeout=12):
    req = _urlreq.Request(url, headers={"User-Agent": "Mozilla/5.0", "Cache-Control": "no-cache"})
    with contextlib.closing(_urlreq.urlopen(req, timeout=timeout)) as r:
        data = r.read()
    if isinstance(data, bytes):
        try:
            data = data.decode("utf-8", "replace")
        except Exception:
            data = data.decode("ascii", "replace")
    return data


def _self_addon_path():
    return os.path.join(_u(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")),
                        "LiClick", "liclick_3dsmax_addon.py")


def _check_update(force=False):
    """拉远端插件 → 比对其内置版本 → 更新就覆盖本地插件文件。返回 (status, msg)。
    status: none(未配置) / latest(已最新) / updated(已更新) / err(失败)。"""
    base = _update_base_url()
    if not base:
        return ("none", u"未配置更新源")
    try:
        new_code = _fetch_text(base + _UPDATE_REMOTE_PY)
    except Exception as e:
        return ("err", u"检查更新失败：" + _txt(e))
    m = re.search(r'ADDON_VERSION\s*=\s*[\'"]([\d.]+)[\'"]', new_code)
    remote_ver = m.group(1) if m else None
    if (not remote_ver) or (u"LiClickDialog" not in new_code) or (len(new_code) < 5000):
        return ("err", u"更新源内容异常，已跳过")
    if _parse_ver(remote_ver) <= _parse_ver(ADDON_VERSION):
        return ("latest", u"已是最新版 v" + ADDON_VERSION)
    dst = _self_addon_path()
    try:
        _makedirs(os.path.dirname(dst))
        if os.path.exists(dst):
            shutil.copy2(dst, dst + ".bak")   # 备份旧版
        with io.open(dst, "w", encoding="utf-8") as f:
            f.write(new_code)
        return ("updated", u"已更新到 v{}，关闭本面板重新打开即可生效".format(remote_ver))
    except Exception as e:
        return ("err", u"写入更新失败：" + _txt(e))


def _txt(x):
    """把任意对象安全转成文本：Python 2.7 下也不会因中文走 ascii 编码而崩。"""
    try:
        return str(x)
    except Exception:
        try:
            return unicode(x)   # noqa: F821  (仅 Python 2 存在)
        except Exception:
            return repr(x)


def _u(s):
    """把可能是 mbcs bytes 的路径(Py2.7 的 expanduser / os.environ 返回值)转成 unicode，
    避免中文用户名路径与 unicode 字面量 os.path.join 时按 ascii 解码而崩。Py3 原样返回。"""
    if s is None or not hasattr(s, "decode"):
        return s
    for enc in ("mbcs", "utf-8"):
        try:
            return s.decode(enc)
        except Exception:
            continue
    try:
        return s.decode("ascii", "ignore")
    except Exception:
        return s


class _CompletedProc(object):
    def __init__(self, rc, out, err):
        self.returncode = rc
        self.stdout = out
        self.stderr = err


def _proc_run(cmd, shell=False, stdin=None, stdout=None, stderr=None,
              creationflags=0, capture_output=False, text=False,
              encoding=None, errors=None, timeout=None):
    if hasattr(subprocess, "run"):  # Python 3
        kw = {"shell": shell, "creationflags": creationflags}
        if stdin is not None: kw["stdin"] = stdin
        if stdout is not None: kw["stdout"] = stdout
        if stderr is not None: kw["stderr"] = stderr
        if capture_output: kw["capture_output"] = True
        if text: kw["text"] = True
        if encoding is not None: kw["encoding"] = encoding
        if errors is not None: kw["errors"] = errors
        if timeout is not None: kw["timeout"] = timeout
        return subprocess.run(cmd, **kw)
    # Python 2.7 fallback
    if capture_output:
        stdout = subprocess.PIPE
        stderr = subprocess.PIPE
    proc = subprocess.Popen(cmd, shell=shell, stdin=stdin, stdout=stdout,
                            stderr=stderr, creationflags=creationflags)
    timer = None
    if timeout is not None:
        def _kill():
            try:
                proc.kill()
            except Exception:
                pass
        timer = threading.Timer(timeout, _kill)
        timer.start()
    try:
        out, err = proc.communicate()
    finally:
        if timer is not None:
            timer.cancel()
    uni = type(u"")
    if (text or encoding) and out is not None and not isinstance(out, uni):
        out = out.decode(encoding or "utf-8", errors or "strict")
    if (text or encoding) and err is not None and not isinstance(err, uni):
        err = err.decode(encoding or "utf-8", errors or "strict")
    return _CompletedProc(proc.returncode, out, err)

# ── 命名规则 ──────────────────────────────────────────────────────────────────

_SUFFIX_TO_VIEW = {

    "_前": "front", "_后": "back", "_左": "left", "_右": "right",

    "_1": "front", "_2": "back", "_3": "left", "_4": "right",

}

_IMG_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}

def scan_folder(folder):

    groups = defaultdict(dict)

    for _name in sorted(os.listdir(folder)):

        f = os.path.join(folder, _name)

        if not os.path.isfile(f) or os.path.splitext(_name)[1].lower() not in _IMG_EXTS:

            continue

        stem = os.path.splitext(_name)[0]

        view = "front"

        base = stem

        for sfx, vname in _SUFFIX_TO_VIEW.items():

            if stem.endswith(sfx):

                view = vname

                base = stem[: -len(sfx)]

                break

        if view not in groups[base]:

            groups[base][view] = f

    return dict(sorted(groups.items()))


def scan_files(file_paths):
    """把一组散图路径按命名规则分组，与 scan_folder 返回相同结构。"""
    groups = defaultdict(dict)
    for f in file_paths:
        _name = os.path.basename(f)
        if not os.path.isfile(f) or os.path.splitext(_name)[1].lower() not in _IMG_EXTS:
            continue
        stem = os.path.splitext(_name)[0]
        view = "front"
        base = stem
        for sfx, vname in _SUFFIX_TO_VIEW.items():
            if stem.endswith(sfx):
                view = vname
                base = stem[: -len(sfx)]
                break
        if view not in groups[base]:
            groups[base][view] = f
    return dict(sorted(groups.items()))

# ── 图片缩放（自动适配 LiClick 上传要求）─────────────────────────────────────

_LICLICK_MIN_PX = 512              # 最大边 < 此值时等比放大（太小 AI 细节差）
_LICLICK_MAX_PX = 2048             # 最大边 > 此值时等比缩小
_LICLICK_MAX_FILE_BYTES = 4 * 1024 * 1024  # 4 MB：尺寸合格但文件超限也缩到 1024px 重编码


def resize_for_upload(image_path):
    """自动检测并调整图片尺寸与文件体积（与 blender 版逻辑一致）。
    · 最大边 < MIN  → 等比放大到 MIN
    · 最大边 > MAX  → 等比缩小到 MAX
    · 尺寸合格但文件 > 4MB → 缩到 1024px 重编码（不超过原尺寸，防误放大）
    · 其余 → 原图直接上传
    缩放后统一存 JPEG（同分辨率体积小很多，规避 413）。
    返回 (上传路径, 是否缩放, 原尺寸str)。
    """
    img = QtGui.QImage(image_path)
    if img.isNull():
        return image_path, False, "?"
    w, h = img.width(), img.height()
    size_str = '{}×{}'.format(w, h)
    max_side = max(w, h)
    if max_side < _LICLICK_MIN_PX:
        target = _LICLICK_MIN_PX
    elif max_side > _LICLICK_MAX_PX:
        target = _LICLICK_MAX_PX
    elif os.path.getsize(image_path) > _LICLICK_MAX_FILE_BYTES:
        target = min(max_side, 1024)
    else:
        if _is_ascii_path(image_path):
            return image_path, False, size_str
        # 中文等非 ASCII 路径：复制成纯英文临时文件再上传（兼容 Py2.7 / subprocess）
        try:
            dst = _ascii_temp(os.path.splitext(image_path)[1].lower() or ".jpg")
            shutil.copy2(image_path, dst)
            return dst, False, size_str
        except Exception:
            return image_path, False, size_str
    scaled = img.scaled(target, target,
                        QtCore.Qt.KeepAspectRatio,
                        QtCore.Qt.SmoothTransformation)
    tmp = _ascii_temp(".jpg")
    scaled.save(tmp, "JPEG", 92)
    return tmp, True, size_str

# ── atlas-skillhub gateway CLI 封装 ───────────────────────────────────────────

def _run_gateway(*args):

    cmd = ["atlas-skillhub", "gateway"] + list(args)

    uid = '{}_{}'.format(os.getpid(), int(time.time() * 1000000.0) % 9999999)

    out_path = os.path.join(_ascii_tempdir(), 'lgw_{}.txt'.format(uid))

    try:

        if os.name == "nt":

            _proc_run(

                '{} 1>"{}" 2>&1'.format(subprocess.list2cmdline(cmd), out_path),

                shell=True, stdin=_DEVNULL,

                creationflags=_CREATE_NO_WINDOW,

            )

        else:

            with io.open(out_path, "w", encoding="utf-8") as fh:

                _proc_run(cmd, stdin=_DEVNULL,

                               stdout=fh, stderr=subprocess.STDOUT)

        with io.open(out_path, encoding="utf-8", errors="replace") as fh:

            raw = fh.read()

    finally:

        try:

            os.unlink(out_path)

        except Exception:

            pass

    lines = [l for l in raw.splitlines()

             if "UV_HANDLE_CLOSING" not in l and "Assertion failed" not in l]

    output = "\n".join(lines).strip()

    if not output:

        raise RuntimeError('命令无输出。原始内容：{}'.format(raw[:300]))

    return output


# ── 可用 AI 模型：在线自动获取（图生3D / 多视图生3D 可用的模型，自动跟随 LiClick 新上线）──
DEFAULT_GEN_MODELS = ["hunyuan-v3.1", "rodin-gen-2.5", "tripo-v3.1", "tripo-P1"]

# 需要"必须填提示词(prompt)"的模型（如 rodin 系列图生3D）；联网拉取时会自动更新
_PROMPT_MODELS = set(["rodin-gen-2.5"])


def _model_needs_prompt(name):
    """该模型是否必须填提示词。"""
    if not name:
        return False
    if name in _PROMPT_MODELS:
        return True
    return name.lower().startswith("rodin")


# 各模型「模型面数」范围与默认值 (min, max, default)
_FACE_SPEC = {
    "hunyuan-v3.1": (10000, 1500000, 1500000),
    "rodin-gen-2.5": (20000, 2000000, 2000000),
    "tripo-v3.1": (500, 2000000, 500000),
    "tripo-P1": (500, 20000, 20000),
}


def _face_spec(name):
    return _FACE_SPEC.get(name, (500, 2000000, 500000))


def _mesh_mode(name):
    """tripo 模型的网格模式（绑定在模型上）。"""
    m = (name or "").lower()
    if "p1" in m:
        return "smart_low_poly"
    if "tripo" in m:
        return "high_precision"
    return None


def _models_cache_path():
    d = os.path.join(_u(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")), "LiClick")
    try:
        _makedirs(d)
    except Exception:
        pass
    return os.path.join(d, "models_cache.json")


def _load_cached_models():
    try:
        with io.open(_models_cache_path(), encoding="utf-8") as fh:
            data = json.load(fh)
        models = data.get("generation_models")
        if isinstance(models, list) and models:
            return [str(x) for x in models]
    except Exception:
        pass
    return None


def _save_cached_models(models):
    try:
        with io.open(_models_cache_path(), "w", encoding="utf-8") as fh:
            json.dump({"generation_models": list(models)}, fh, ensure_ascii=False)
    except Exception:
        pass


def _fetch_generation_models():
    """查询 liclick gateway 当前支持「图生3D(generation)」的模型列表；失败返回 None。
    解析 get-tool 描述能力矩阵里 generation 行括号内的模型名，
    LiClick 上线新模型后会自动出现在这里。"""
    try:
        out = _run_gateway("get-tool", "--service", "liclick", "--tool", "generate_model_3d")
    except Exception:
        return None
    if not out:
        return None
    try:
        gen = None
        for ln in out.splitlines():
            s = ln.strip()
            if not re.match(r"^-\s*generation", s):
                continue
            for grp in re.findall(r"[（(]([^）)]+)[）)]", s):
                parts = [p.strip() for p in re.split(r"[/／]", grp) if p.strip()]
                parts = [p for p in parts if re.match(r"^[A-Za-z][A-Za-z0-9._-]+$", p)]
                if parts and any(re.match(r"^(hunyuan|tripo|rodin|meshy)", p) for p in parts):
                    gen = parts
                    break
            if gen:
                break
        if not gen:
            return None
        # 标记"必须填提示词(prompt)"的模型（如 rodin-gen-2.5），界面据此高亮/灰显提示词栏
        need_prompt = set()
        for ln in out.splitlines():
            s = ln.strip()
            m = re.match(r"^-\s*([A-Za-z][A-Za-z0-9._-]+)[：:]", s)
            if m and ("prompt" in s) and ("必填" in s):
                need_prompt.add(m.group(1))
        if need_prompt:
            global _PROMPT_MODELS
            _PROMPT_MODELS = need_prompt
        return gen
    except Exception:
        return None
    return None


def _unwrap_gateway(text):

    s = text.strip()

    for _ in range(3):

        try:

            parsed = json.loads(s)

        except Exception:

            break

        if isinstance(parsed, list):

            for item in parsed:

                if isinstance(item, dict):

                    inner = item.get("text") or item.get("content") or ""

                    if inner:

                        s = inner

                        break

            else:

                break

        elif isinstance(parsed, dict):

            inner = parsed.get("text") or parsed.get("content") or ""

            if inner and isinstance(inner, str):

                s = inner

            else:

                break

        elif isinstance(parsed, str):

            s = parsed

        else:

            break

    return s

def _parse_asset_id(text):

    for s in (text, _unwrap_gateway(text), text.replace('\\"', '"')):

        m = re.search(r'"asset_id"\s*:\s*"([^"]+)"', s)

        if m:

            return m.group(1)

        m = re.search(r'"id"\s*:\s*"([0-9a-f\-]{20,})"', s, re.I)

        if m:

            return m.group(1)

    return None

def _parse_task_id(text):

    for s in (text, _unwrap_gateway(text), text.replace('\\"', '"')):

        for key in ("task_id", "request_id"):

            m = re.search('"{}"\\s*:\\s*"([^"]+)"'.format(key), s)

            if m:

                return m.group(1)

        m = re.search(r'task_id["\s:：，,]+([0-9a-fA-F]{8}-[0-9a-fA-F\-]{20,})', s)

        if m:

            return m.group(1)

        m = re.search(r'\b([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'

                      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\b', s)

        if m:

            return m.group(1)

    return None

def _parse_model_url(text):

    s = text.replace('\\/', '/')

    m = re.search(r'https://[^\s"\'<>\\]*?\.(?:glb|fbx|obj|stl|usdz)[^\s"\'<>\\]*',

                  s, re.I)

    return m.group(0) if m else None

def _download_model(url, dest):

    req = _urlreq.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"})

    with contextlib.closing(_urlreq.urlopen(req, timeout=120)) as resp, open(dest, "wb") as fh:

        while True:

            chunk = resp.read(65536)

            if not chunk:

                break

            fh.write(chunk)

# ── glb → fbx 转换 ────────────────────────────────────────────────────────────

_CONVERT_SCRIPT = r"""
import bpy, sys

argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
bpy.ops.export_scene.fbx(filepath=dst, path_mode="COPY", embed_textures=True,
                         use_selection=False, apply_unit_scale=True,
                         bake_space_transform=False)

# 额外把 base color(颜色)贴图导成 PNG，供 3ds Max 单独贴色（确保视口能看到颜色）
try:
    tex_out = dst + ".basecolor.png"

    def _img_is_color(im):
        nm = (getattr(im, "name", "") or "").lower()
        for bad in ("normal", "_nrm", "rough", "metal", "_orm", "_arm",
                    "occlusion", "_ao", "specular", "_spec", "emiss", "height", "disp"):
            if bad in nm:
                return False
        try:
            cs = (im.colorspace_settings.name or "").lower()
        except Exception:
            cs = ""
        if cs in ("non-color", "noncolor", "raw", "linear"):
            return False
        return True

    img = None
    # 1) 沿 Principled BSDF 的 Base Color 链找贴图（可能经过中间节点）
    for m in bpy.data.materials:
        if not getattr(m, "use_nodes", False) or not m.node_tree:
            continue
        bsdf = None
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                bsdf = n
                break
        if bsdf is None:
            continue
        bc = bsdf.inputs.get("Base Color")
        if bc is None or not bc.is_linked:
            continue
        seen = set()
        stack = [bc.links[0].from_node]
        while stack:
            nd = stack.pop()
            if id(nd) in seen:
                continue
            seen.add(id(nd))
            if nd.type == "TEX_IMAGE" and nd.image:
                img = nd.image
                break
            for ip in nd.inputs:
                try:
                    if ip.is_linked:
                        stack.append(ip.links[0].from_node)
                except Exception:
                    pass
        if img is not None:
            break
    # 2) 退一步：只认"明确命名为底色/反照率"的颜色图，避免误抓法线/粗糙等（抓不到就交给 Max 处理顶点色）
    if img is None:
        wants = ("basecolor", "base_color", "albedo", "diffuse", "_col", "_color", "baked")
        for i in bpy.data.images:
            if not (getattr(i, "has_data", False) and tuple(i.size) != (0, 0)):
                continue
            if not _img_is_color(i):
                continue
            nm = (getattr(i, "name", "") or "").lower()
            if any(w in nm for w in wants):
                img = i
                break
    if img is not None:
        img.filepath_raw = tex_out
        img.file_format = "PNG"
        img.save()
        print("BASECOLOR_OK")
    else:
        print("BASECOLOR_NONE")
except Exception as e:
    print("BASECOLOR_ERR", e)

print("CONVERT_OK")
"""

def _find_blender():

    import glob

    try:
        from shutil import which
    except ImportError:
        def which(prog):
            for d in (os.environ.get("PATH") or "").split(os.pathsep):
                for ext in ("", ".exe", ".bat", ".cmd"):
                    cand = os.path.join(d, prog + ext)
                    if os.path.isfile(cand):
                        return cand
            return None

    env = os.environ.get("BLENDER_EXE")

    if env and os.path.exists(env):

        return env

    pats = [

        r"C:\Program Files\Blender Foundation\*\blender.exe",

        r"C:\Program Files (x86)\Blender Foundation\*\blender.exe",

    ]

    found = []

    for p in pats:

        found += glob.glob(p)

    if found:

        found.sort(reverse=True)

        return found[0]

    return which("blender")


# ── 便携 Blender 自动下载（本机没装时，下载一次缓存到 %LOCALAPPDATA%\LiClick\blender）──
_BLENDER_DL_URLS = [
    "https://download.blender.org/release/Blender4.2/blender-4.2.5-windows-x64.zip",
    "https://download.blender.org/release/Blender4.2/blender-4.2.3-windows-x64.zip",
    "https://download.blender.org/release/Blender3.6/blender-3.6.14-windows-x64.zip",
]
_blender_lock = threading.Lock()


def _portable_blender_dir():
    return os.path.join(_u(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")),
                        "LiClick", "blender")


def _find_portable_blender():
    base = _portable_blender_dir()
    if not os.path.isdir(base):
        return None
    for root, _dirs, files in os.walk(base):
        if "blender.exe" in files:
            return os.path.join(root, "blender.exe")
    return None


def _download_file(url, dest, progress_cb=None, label="下载"):
    req = _urlreq.Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "*/*"})
    with contextlib.closing(_urlreq.urlopen(req, timeout=60)) as resp:
        try:
            total = int(resp.headers.get("Content-Length") or 0)
        except Exception:
            total = 0
        got = 0
        last = -1
        with open(dest, "wb") as fh:
            while True:
                chunk = resp.read(262144)
                if not chunk:
                    break
                fh.write(chunk)
                got += len(chunk)
                if progress_cb:
                    mb = int(got // 1048576)
                    if mb != last and mb % 5 == 0:
                        last = mb
                        if total:
                            progress_cb('{} {}/{} MB'.format(label, mb, int(total // 1048576)))
                        else:
                            progress_cb('{} {} MB'.format(label, mb))


def _ensure_blender(progress_cb=None):
    """返回可用 blender.exe；本机没装就自动下载便携版（仅一次，带缓存 + 线程锁）。失败返回 None。"""
    exe = _find_blender() or _find_portable_blender()
    if exe:
        return exe
    with _blender_lock:
        exe = _find_blender() or _find_portable_blender()   # 双检：可能别的线程已下好
        if exe:
            return exe
        base = _portable_blender_dir()
        try:
            _makedirs(base)
        except Exception:
            pass
        zpath = os.path.join(_ascii_tempdir(), "blender_portable.zip")
        ok = False
        for url in _BLENDER_DL_URLS:
            try:
                if progress_cb:
                    progress_cb("首次配置：下载便携 Blender（约 370MB，仅一次）...")
                _download_file(url, zpath, progress_cb, label="下载 Blender")
                ok = os.path.exists(zpath) and os.path.getsize(zpath) > 100 * 1024 * 1024
                if ok:
                    break
            except Exception:
                ok = False
        if not ok:
            try:
                if os.path.exists(zpath):
                    os.remove(zpath)
            except Exception:
                pass
            return None
        try:
            if progress_cb:
                progress_cb("解压 Blender（首次，稍候）...")
            import zipfile
            zf = zipfile.ZipFile(zpath)
            try:
                zf.extractall(base)
            finally:
                zf.close()
        except Exception:
            return None
        finally:
            try:
                os.remove(zpath)
            except Exception:
                pass
        return _find_portable_blender()


def _ensure_convert_script():

    p = os.path.join(_ascii_tempdir(), "liclick_gltf2fbx.py")

    with io.open(p, "w", encoding="utf-8") as f:

        f.write(_CONVERT_SCRIPT)

    return p

def _convert_to_fbx(glb_path, exe=None):

    if exe is None:
        exe = _find_blender() or _find_portable_blender()

    if not exe:

        raise RuntimeError(

            "未找到 Blender，无法把 glb 转为 fbx。请安装 Blender，"

            "或设置环境变量 BLENDER_EXE 指向 blender.exe。"

        )

    fbx_path = os.path.splitext(glb_path)[0] + ".fbx"
    script = _ensure_convert_script()

    # 中文路径不直接传给 Blender subprocess（Py2.7 下会编码出错）：
    # 转换走纯英文临时路径，完成后再搬回最终（可能带中文）的 fbx 路径。
    src_glb, dst_fbx = glb_path, fbx_path
    use_tmp = not (_is_ascii_path(glb_path) and _is_ascii_path(fbx_path))
    if use_tmp:
        try:
            src_glb = _ascii_temp(".glb")
            shutil.copy2(glb_path, src_glb)
            dst_fbx = _ascii_temp(".fbx")
        except Exception:
            src_glb, dst_fbx, use_tmp = glb_path, fbx_path, False

    kw = {}
    if os.name == "nt":
        kw["creationflags"] = _CREATE_NO_WINDOW
    r = _proc_run(
        [exe, "--background", "--python", script, "--", src_glb, dst_fbx],
        stdin=_DEVNULL, capture_output=True, text=True,
        encoding="utf-8", errors="replace", timeout=300, **kw
    )

    out = (r.stdout or "") + (r.stderr or "")
    if "CONVERT_OK" not in out or not os.path.exists(dst_fbx):
        raise RuntimeError('glb→fbx 转换失败：{}'.format(out[-300:]))

    if use_tmp:
        bc_src = dst_fbx + ".basecolor.png"
        bc_dst = fbx_path + ".basecolor.png"
        try:
            if os.path.exists(fbx_path):
                os.remove(fbx_path)
            shutil.move(dst_fbx, fbx_path)
        except Exception:
            fbx_path = dst_fbx
            bc_dst = bc_src
        try:
            if bc_src != bc_dst and os.path.exists(bc_src):
                if os.path.exists(bc_dst):
                    os.remove(bc_dst)
                shutil.move(bc_src, bc_dst)
        except Exception:
            pass
        try:
            if src_glb != glb_path and os.path.exists(src_glb):
                os.remove(src_glb)
        except Exception:
            pass
    return fbx_path

# ── 后台 Worker ───────────────────────────────────────────────────────────────

# ── 暂停 / 继续：set=运行中，clear=已暂停（与 blender 版一致）──
_pause_event = threading.Event()
_pause_event.set()


def _interruptible_sleep(seconds):
    """可中断 sleep：暂停时提前返回，不必白等满 15 秒。"""
    deadline = time.time() + seconds
    while time.time() < deadline:
        time.sleep(0.5)
        if not _pause_event.is_set():
            return


class ModelFetchWorker(QtCore.QThread):

    sig_models = Signal(list)

    def run(self):
        try:
            models = _fetch_generation_models()
        except Exception:
            models = None
        if models:
            self.sig_models.emit(models)


class UpdateWorker(QtCore.QThread):
    """后台检查/下载更新，不阻塞界面。manual=True 表示用户手动点的（无论结果都提示）。"""

    sig_update = Signal(str, str, bool)   # status, msg, manual

    def __init__(self, manual=False, parent=None):
        super(UpdateWorker, self).__init__(parent)
        self.manual = manual

    def run(self):
        try:
            st, msg = _check_update(False)
        except Exception as e:
            st, msg = "err", _txt(e)
        self.sig_update.emit(st, msg, self.manual)


class GenWorker(QtCore.QThread):

    sig_progress = Signal(int, str, str)

    sig_done = Signal(int, str, str)

    sig_fail = Signal(int, str, str)

    def __init__(self, idx, group_name, views, settings, parent=None):

        super(GenWorker, self).__init__(parent)

        self.idx = idx

        self.group_name = group_name

        self.views = views

        self.s = dict(settings or {})

        self.model = self.s.get("model", "")

    def run(self):

        idx = self.idx

        stage = "上传参考图"

        try:

            stage = "上传参考图"

            self.sig_progress.emit(idx, "uploading", '上传 {} 张图片...'.format(len(self.views)))

            uploaded = {}

            items = list(self.views.items())

            for i, (view, path) in enumerate(items, 1):

                if not _pause_event.is_set():
                    self.sig_progress.emit(idx, "uploading", '上传图片 {}/{}（{}）[已暂停]'.format(i, len(items), view))
                    _pause_event.wait()

                self.sig_progress.emit(idx, "uploading", '上传图片 {}/{}（{}）'.format(i, len(items), view))

                asset_id = None
                for _try in range(3):
                    try:
                        out = _run_gateway("call-tool", "--service", "liclick",
                                           "--tool", "upload_asset", "--file", 'file_path={}'.format(path))
                        asset_id = _parse_asset_id(out)
                    except Exception:
                        asset_id = None
                    if asset_id:
                        break
                    self.sig_progress.emit(idx, "uploading", '上传重试（{} 第 {} 次）'.format(view, _try + 2))
                    _interruptible_sleep(3)

                if not asset_id:

                    raise RuntimeError('上传 {} 图失败（重试 3 次仍未返回 asset_id）'.format(view))

                uploaded[view] = 'asset:{}'.format(asset_id)

            stage = "提交生成任务"

            if not _pause_event.is_set():
                self.sig_progress.emit(idx, "submitting", "等待继续后提交 [已暂停]")
                _pause_event.wait()

            self.sig_progress.emit(idx, "submitting", "提交生成任务...")

            args = {"request_type": "generation", "model": self.model}

            args.update(uploaded)

            # 按模型组装该模型支持的参数（和 LiClick 面板一致）
            ml = (self.model or "").lower()
            ep = {}

            face = self.s.get("face")
            if face:
                ep["face_count"] = int(face)

            if ml.startswith("rodin"):
                # rodin：创意描述(顶层 prompt) + 生成质量 tier + 材质配置 material
                if self.s.get("prompt"):
                    args["prompt"] = self.s["prompt"]
                ep["tier"] = self.s.get("quality", "Gen-2.5-High")
                ep["material"] = self.s.get("material", "PBR")
            else:
                # 混元 / tripo：生成纹理 + PBR
                gt = bool(self.s.get("gen_tex", True))
                ep["generate_texture"] = gt
                ep["enable_pbr"] = bool(self.s.get("pbr", True)) if gt else False
                if ml.startswith("tripo"):
                    mm = _mesh_mode(self.model)
                    if mm:
                        ep["mesh_mode"] = mm
                    ep["polygon_type"] = "triangle"

            args["extra_params"] = ep

            # ensure_ascii=True：中文创意描述转成 \uXXXX，命令行参数纯 ASCII，
            # 避免旧版 Max(Py2.7) 在 subprocess 里按 ascii 编码中文而报错；网关侧 JSON 解析会还原中文。
            out = _run_gateway("call-tool", "--service", "liclick",

                               "--tool", "generate_model_3d",

                               "--args", json.dumps(args))

            task_id = _parse_task_id(out)

            if not task_id:

                raise RuntimeError('未获取到 task_id。响应：{}'.format(out[:300]))

            stage = "等待生成（轮询）"

            self.sig_progress.emit(idx, "polling", '生成中 ({}…)'.format(task_id[:8]))

            for attempt in range(80):

                _interruptible_sleep(15)
                if not _pause_event.is_set():
                    self.sig_progress.emit(idx, "polling", '已暂停（{}…）'.format(task_id[:8]))
                    _pause_event.wait()

                self.sig_progress.emit(idx, "polling", '等待完成（第 {} 次轮询）'.format(attempt + 1))

                out = None
                for _q in range(3):     # 同一轮内先快速重试几次，扛住瞬时空响应/网关并发抖动
                    try:
                        out = _run_gateway("call-tool", "--service", "liclick",
                                           "--tool", "get_task_status",
                                           'task_id={}'.format(task_id), "task_type=model_3d")
                        break
                    except Exception:
                        out = None
                        _interruptible_sleep(3)
                if not out:
                    # 仍无响应：绝不判失败，等下一轮再试（多组并行时尤其常见）
                    self.sig_progress.emit(idx, "polling", '查询无响应，稍后重试（第 {} 次）'.format(attempt + 1))
                    continue

                if "完成" in out or "Finished" in out:

                    url = _parse_model_url(out)

                    if not url:

                        self._write_debug(url, out)

                        raise RuntimeError("任务完成但未找到模型 URL（详情见桌面日志）")

                    stage = "下载模型"

                    self.sig_progress.emit(idx, "downloading", "下载模型文件...")

                    em = re.search(r'\.(glb|fbx|obj|stl|usdz)', url, re.I)

                    ext = em.group(0) if em else ".glb"

                    safe = re.sub(r'[\\/:*?"<>|]', '_', self.group_name).strip() or "model"

                    out_dir = os.path.join(_u(os.path.expanduser("~")), "Desktop", "LiClick_Models")

                    _makedirs(out_dir)

                    dest = os.path.join(out_dir, '{}{}'.format(safe, ext))

                    try:

                        _download_model(url, dest)

                    except Exception as dl_exc:

                        self._write_debug(url, out)

                        raise RuntimeError('下载失败({})。详情见桌面 liclick_debug_{}.txt'.format(dl_exc, safe))

                    final_path = dest

                    if dest.lower().endswith(".glb"):

                        stage = "准备转换器"

                        # 本机没装 Blender 就自动下载便携版（仅一次）；失败再退回直接导 glb
                        blender = _ensure_blender(
                            lambda m: self.sig_progress.emit(idx, "converting", m))

                        if blender:

                            stage = "转换 glb→fbx"

                            self.sig_progress.emit(idx, "converting", "用 Blender 转换 glb → fbx...")

                            final_path = _convert_to_fbx(dest, blender)

                        else:

                            # 实在拿不到 Blender 也不卡死：直接让 Max 导入 glb（2024+ 原生支持 glTF）
                            self.sig_progress.emit(idx, "converting", "未能获取 Blender，直接导入 glb（需 Max 2024+）...")

                            final_path = dest

                    self.sig_done.emit(idx, final_path, self.group_name)

                    return

                if "Failed" in out or "失败" in out:

                    inner = _unwrap_gateway(out)

                    em = re.search(r'"err_msg"\s*:\s*"([^"]+)"', inner) or re.search(r'"err_msg"\s*:\s*"([^"]+)"', out)

                    raise RuntimeError(em.group(1) if em else "任务失败（无详情）")

            raise RuntimeError("超时（20 分钟内未完成）")

        except Exception as exc:

            self.sig_fail.emit(idx, stage, _txt(exc))

    def _write_debug(self, url, out):

        try:

            safe = re.sub(r'[\\/:*?"<>|]', '_', self.group_name).strip() or "model"

            logp = os.path.join(_u(os.path.expanduser("~")), "Desktop", 'liclick_debug_{}.txt'.format(safe))

            with io.open(logp, "w", encoding="utf-8") as lf:

                lf.write("=== 提取出的 URL ===\n")

                lf.write(str(url) + "\n\n=== 完整响应 ===\n")

                lf.write(out)

        except Exception:

            pass

# ── 3ds Max 导入 + 摆放 ───────────────────────────────────────────────────────

_IMPORT_TARGET_SIZE = 100.0   # 导入后统一把每个模型缩放到"最大边≈此值(场景单位)"，避免大小不一


def _unique_max_name(name, exclude=None):
    """场景里已有同名物体时，自动在名字后加 01/02… 区分，避免冲突。"""
    try:
        exclude = exclude or []
        used = []
        for o in rt.objects:
            try:
                if o in exclude:
                    continue
                used.append(o.name)
            except Exception:
                pass
        if name not in used:
            return name
        i = 1
        while True:
            cand = u'{}{:02d}'.format(name, i)
            if cand not in used:
                return cand
            i += 1
    except Exception:
        return name


def _get_self_color_file(mat):
    """只读地从模型自带材质取出"颜色贴图文件路径"。
    只做属性读取(getattr / classof / fileName)，不调用易让 Max 崩溃的 showTextureMap、不改场景。
    取顶层材质的 base color / diffuse 位图，文件存在就返回其路径；否则返回 None。"""
    if mat is None:
        return None
    try:
        if mat == rt.undefined:
            return None
    except Exception:
        return None
    mp = None
    for attr in ("base_color_map", "baseColorMap", "diffuseMap"):
        try:
            v = getattr(mat, attr)
        except Exception:
            v = None
        if v is not None:
            mp = v
            break
    if mp is None:
        return None
    try:
        if rt.classof(mp) == rt.Bitmaptexture:
            fn = mp.fileName
            # 必须带扩展名且是 Max 能识别的图片：fbx 内嵌贴图常被解压成"无扩展名"文件，Max 加载不了→灰模
            if fn and os.path.exists(fn):
                ext = os.path.splitext(fn)[1].lower()
                if ext in (".png", ".jpg", ".jpeg", ".bmp", ".tga", ".tif", ".tiff", ".exr", ".dds", ".gif"):
                    return fn
    except Exception:
        pass
    return None


def _max_import_and_place(filepath, name, layout_x, gap=100.0):

    before = [n for n in rt.objects]

    try:

        rt.importFile(filepath, rt.Name("noPrompt"))

    except Exception:

        pass

    new = [n for n in rt.objects if n not in before]

    if not new:

        raise RuntimeError(

            "导入后未出现新对象：当前 3ds Max 可能不支持该格式直接导入。\n"

            "glb 解决办法二选一：① 安装 Blender（本工具会自动转成 fbx 再导入，且带贴图）；"

            "② 用 Max 2024+（原生支持 glTF）。模型已存到桌面 LiClick_Models 可手动处理。"

        )

    name = _unique_max_name(name, exclude=new)   # 重名自动加 01/02，避免与场景里已有物体冲突

    if len(new) > 1:

        grp = rt.group(new, name=name)

    else:

        grp = new[0]

        grp.name = name

    # 上色（统一用"新建标准材质"来贴，避免对自带材质调用易崩接口导致 Max 闪退）：
    #   ① 自带材质里的真实贴图文件(UV 最准) → ② Blender 提取的颜色贴图 → ③ 顶点色
    try:
        applied = False

        # 取一张颜色贴图文件：优先 Blender 提取的 basecolor.png（带正确扩展名、能加载、UV 匹配——已用 3dsmaxbatch 实测正确显示）；
        # 没有再退回模型自带材质里"带扩展名能加载"的贴图（fbx 内嵌解压出的无扩展名贴图会被 _get_self_color_file 跳过）。
        src_tex = None
        bc_png = filepath + ".basecolor.png"
        if os.path.exists(bc_png) and os.path.getsize(bc_png) > 0:
            src_tex = bc_png
        if not src_tex:
            for o in new:
                try:
                    f = _get_self_color_file(o.material)
                    if f:
                        src_tex = f
                        break
                except Exception:
                    pass

        if src_tex:
            try:
                # 复制成『纯英文路径 + 正确扩展名』再加载：修复中文路径 + Blender 把 JPEG 存成 .png 导致老版 Max 加载失败→灰模
                src_tex = _ascii_image_copy(src_tex)
                bmp = rt.Bitmaptexture(fileName=src_tex)
                mat = rt.StandardMaterial(name=(name + "_mat"))
                mat.diffuseMap = bmp
                try:
                    mat.diffuseMapEnable = True
                except Exception:
                    pass
                for o in new:
                    try:
                        o.material = mat
                    except Exception:
                        pass
                try:
                    rt.showTextureMap(mat, bmp, True)
                except Exception:
                    pass
                applied = True
            except Exception:
                pass

        # ③ 还没有 → 顶点色模型，用顶点色当漫反射显示
        if not applied:
            has_vc = False
            for o in new:
                try:
                    if rt.getNumCPVVerts(o) > 0:
                        has_vc = True
                        break
                except Exception:
                    pass
            if has_vc:
                try:
                    vc = rt.VertexColor()
                    matv = rt.StandardMaterial(name=(name + "_vcmat"))
                    matv.diffuseMap = vc
                    for o in new:
                        try:
                            o.material = matv
                        except Exception:
                            pass
                    try:
                        rt.showTextureMap(matv, vc, True)
                    except Exception:
                        pass
                except Exception:
                    pass
    except Exception:
        pass

    # 统一大小：把每个模型缩放到"最大边 ≈ _IMPORT_TARGET_SIZE"，避免各模型大小不一
    try:
        b0, b1 = grp.min, grp.max
        maxdim = max(b1.x - b0.x, b1.y - b0.y, b1.z - b0.z)
        if maxdim > 1e-4:
            f = _IMPORT_TARGET_SIZE / maxdim
            try:
                grp.pivot = grp.center
            except Exception:
                pass
            rt.scale(grp, rt.Point3(f, f, f))
    except Exception:
        pass

    # 落到地面 (z=0)、居中 y=0、沿 X 轴一字排开
    try:
        bmin, bmax = grp.min, grp.max
        cx = (bmin.x + bmax.x) / 2.0
        cy = (bmin.y + bmax.y) / 2.0
        minz = bmin.z
        grp.pivot = rt.Point3(cx, cy, minz)
        width = bmax.x - bmin.x
        grp.position = rt.Point3(layout_x + width / 2.0, 0.0, 0.0)
        try:
            rt.completeRedraw()   # 强制刷新视口，确保材质/贴图立刻显示（部分版本不会自动刷新）
        except Exception:
            pass
        return layout_x + width + gap
    except Exception:
        return layout_x + _IMPORT_TARGET_SIZE + gap

def _compute_start_x(gap=100.0):

    max_x = None

    for o in rt.objects:

        try:

            mx = o.max.x

            max_x = mx if max_x is None else max(max_x, mx)

        except Exception:

            pass

    return 0.0 if max_x is None else max_x + gap

# ── 拖动调值 SpinBox ─────────────────────────────────────────────────────────

class StyledCheckBox(QtWidgets.QCheckBox):

    """Checkbox whose indicator is custom-painted so the checkmark is always visible."""

    _SZ = 15

    def __init__(self, *args, **kwargs):

        super(StyledCheckBox, self).__init__(*args, **kwargs)

        self.setAttribute(QtCore.Qt.WA_Hover, True)

    def paintEvent(self, event):

        p = QtGui.QPainter(self)

        p.setRenderHint(QtGui.QPainter.Antialiasing)

        sz = self._SZ

        cy = (self.height() - sz) // 2

        cx = 1

        hov = self.underMouse()

        chk = self.isChecked()

        ena = self.isEnabled()

        # box

        if not ena:

            if chk:

                bg   = QtGui.QColor(46, 84, 122)     # 禁用但已勾：暗蓝，仍能看出是"勾选"状态

                brdr = QtGui.QColor(96, 136, 178)

            else:

                bg   = QtGui.QColor(32, 34, 42)

                brdr = QtGui.QColor(58, 62, 72)

        elif chk:

            bg   = QtGui.QColor(60, 128, 200)

            brdr = QtGui.QColor(150, 195, 245) if hov else QtGui.QColor(130, 175, 230)

        elif hov:

            bg   = QtGui.QColor(30, 36, 48)

            brdr = QtGui.QColor(140, 165, 200)

        else:

            bg   = QtGui.QColor(22, 26, 34)

            brdr = QtGui.QColor(100, 112, 130)

        p.setBrush(QtGui.QBrush(bg))

        p.setPen(QtGui.QPen(brdr, 1.5))

        p.drawRoundedRect(cx + 0.75, cy + 0.75, sz - 1.5, sz - 1.5, 3, 3)

        # checkmark — 勾选时一律画（禁用态画暗一点），避免锁定时看着像没勾

        if chk:

            ck = QtGui.QPen(QtGui.QColor(255, 255, 255) if ena else QtGui.QColor(205, 215, 228), 2.0)

            ck.setCapStyle(QtCore.Qt.RoundCap)

            ck.setJoinStyle(QtCore.Qt.RoundJoin)

            p.setPen(ck)

            f = sz / 15.0

            p.drawLine(

                QtCore.QPointF(cx + 3 * f,        cy + sz * 0.57),

                QtCore.QPointF(cx + sz * 0.43,    cy + sz * 0.80),

            )

            p.drawLine(

                QtCore.QPointF(cx + sz * 0.43,    cy + sz * 0.80),

                QtCore.QPointF(cx + (sz-3) * f,   cy + sz * 0.26),

            )

        # text — muted when disabled

        p.setPen(QtGui.QColor(110, 118, 132) if not ena else QtGui.QColor(192, 206, 224))

        p.setFont(self.font())

        tx = cx + sz + 6

        p.drawText(

            QtCore.QRect(tx, 0, self.width() - tx, self.height()),

            QtCore.Qt.AlignVCenter | QtCore.Qt.AlignLeft,

            self.text(),

        )

        p.end()

class _DragSpinMixin(object):

    """鼠标左键横向拖动即可调整数值；点击仍可正常输入。"""

    def _drag_init(self):

        self._drag_x0 = self._drag_v0 = None

        self._dragging = False

        le = self.lineEdit()

        le.setCursor(QtCore.Qt.SizeHorCursor)

        le.installEventFilter(self)

    def eventFilter(self, obj, ev):

        if obj is not self.lineEdit():

            return False

        T = QtCore.QEvent

        if ev.type() == T.MouseButtonPress and ev.button() == QtCore.Qt.LeftButton:

            self._drag_x0 = ev.pos().x()

            self._drag_v0 = float(self.value())

            self._dragging = False

        elif ev.type() == T.MouseMove and (ev.buttons() & QtCore.Qt.LeftButton):

            if self._drag_x0 is not None:

                d = ev.pos().x() - self._drag_x0

                if not self._dragging and abs(d) > 3:

                    self._dragging = True

                    self.lineEdit().clearFocus()

                    QtWidgets.QApplication.setOverrideCursor(QtCore.Qt.SizeHorCursor)

                if self._dragging:

                    nv = self._drag_v0 + d * self.singleStep() * 0.3

                    self.setValue(max(self.minimum(), min(self.maximum(), nv)))

                    return True

        elif ev.type() == T.MouseButtonRelease:

            if self._dragging:

                QtWidgets.QApplication.restoreOverrideCursor()

                self._dragging = False

                self._drag_x0 = None

                return True

            self._drag_x0 = None

        return False

class DragSpinBox(_DragSpinMixin, QtWidgets.QSpinBox):

    def __init__(self, *a, **kw):

        super(DragSpinBox, self).__init__(*a, **kw)

        self._drag_init()

class DragDoubleSpinBox(_DragSpinMixin, QtWidgets.QDoubleSpinBox):

    def __init__(self, *a, **kw):

        super(DragDoubleSpinBox, self).__init__(*a, **kw)

        self._drag_init()


class CheckListWidget(QtWidgets.QListWidget):
    """整行任意位置点击即可切换勾选；按住左键上下滑动可连续勾选 / 取消多行。"""

    def __init__(self, *a, **kw):
        super(CheckListWidget, self).__init__(*a, **kw)
        self._paint = None   # 滑选时要刷成的目标勾选状态（None=非滑选）

    def _evt_pos(self, e):
        try:
            return e.position().toPoint()   # PySide6
        except Exception:
            return e.pos()                  # PySide2

    def _checkable(self, it):
        return it is not None and bool(it.flags() & QtCore.Qt.ItemIsUserCheckable)

    def mousePressEvent(self, e):
        self._paint = None
        try:
            if e.button() == QtCore.Qt.LeftButton:
                it = self.itemAt(self._evt_pos(e))
                if self._checkable(it):
                    # 目标状态 = 与按下项相反：按下即切换它，并以此状态向滑过的行刷
                    self._paint = (QtCore.Qt.Unchecked
                                   if it.checkState() == QtCore.Qt.Checked
                                   else QtCore.Qt.Checked)
                    it.setCheckState(self._paint)
        except Exception:
            self._paint = None
        super(CheckListWidget, self).mousePressEvent(e)

    def mouseMoveEvent(self, e):
        try:
            if self._paint is not None and (e.buttons() & QtCore.Qt.LeftButton):
                it = self.itemAt(self._evt_pos(e))
                if self._checkable(it) and it.checkState() != self._paint:
                    it.setCheckState(self._paint)
        except Exception:
            pass
        super(CheckListWidget, self).mouseMoveEvent(e)

    def mouseReleaseEvent(self, e):
        painting = self._paint is not None
        self._paint = None
        if painting:
            # 勾选已在 press/move 里处理，吞掉本次 release，避免原生勾选框再切换一次造成双切
            e.accept()
            return
        super(CheckListWidget, self).mouseReleaseEvent(e)


# ── 深色扁平样式 ──────────────────────────────────────────────────────────────

_STYLE = """

QWidget {

    background: rgb(38,42,50);

    color: rgb(192,206,224);

    font-family: "Microsoft YaHei";

    font-size: 9pt;

}

QGroupBox {

    border: 1px solid rgb(82,86,96);

    border-radius: 4px;

    margin-top: 12px;

    padding-top: 6px;

}

QGroupBox::title {

    subcontrol-origin: margin;

    subcontrol-position: top left;

    left: 10px;

    padding: 0 5px;

    color: rgb(218,228,244);

    background: transparent;

    font-size: 10pt;

    font-weight: bold;

}

QGroupBox#cfg_box  { border-left: 3px solid rgb(86,122,170); }

QGroupBox#rule_box { border-left: 3px solid rgb(90,144,108); }

QPushButton {

    background: rgb(18,18,18);

    color: rgb(205,212,222);

    border: 1px solid rgb(90,90,90);

    border-radius: 3px;

    padding: 4px 8px;

}

QPushButton:hover   { background: rgb(88,88,88); }

QPushButton:pressed { background: rgb(122,122,122); }

QPushButton:disabled {

    color: rgb(75,80,92);

    border: 1px solid rgb(52,56,64);

}

QLineEdit {

    background: rgb(22,24,28);

    color: rgb(210,218,230);

    border: 1px solid rgb(90,94,104);

    border-radius: 2px;

    padding: 2px 4px;

    selection-background-color: rgb(86,106,170);

}

QLineEdit:disabled {
    background: rgb(32,34,40);
    color: rgb(96,100,112);
    border: 1px solid rgb(52,56,64);
}

QComboBox {

    background: rgb(22,24,28);

    color: rgb(210,218,230);

    border: 1px solid rgb(90,94,104);

    border-radius: 2px;

    padding: 2px 4px;

}

QComboBox::drop-down {

    subcontrol-origin: padding;

    subcontrol-position: top right;

    width: 18px;

    border-left: 1px solid rgb(90,94,104);

}

QComboBox QAbstractItemView {

    background: rgb(26,30,40);

    color: rgb(210,218,230);

    border: 2px solid rgb(86,122,170);

    selection-background-color: rgb(58,82,140);

    selection-color: rgb(225,232,244);

    outline: none;

    padding: 2px 0;

}

QComboBox QAbstractItemView::item {

    padding: 5px 8px;

    min-height: 22px;

}

QComboBox QAbstractItemView::item:hover {

    background: rgb(46,54,72);

    color: rgb(220,228,240);

}

QSpinBox, QDoubleSpinBox {

    background: rgb(22,24,28);

    color: rgb(210,218,230);

    border: 1px solid rgb(90,94,104);

    border-radius: 2px;

    padding: 2px 4px;

}

/* 锁定(禁用)时统一变灰：下拉/数字框/标签/单选都跟着灰，避免"文字仍亮、像没锁"的不一致 */
QComboBox:disabled,
QSpinBox:disabled, QDoubleSpinBox:disabled {
    background: rgb(32,34,40);
    color: rgb(104,109,122);
    border: 1px solid rgb(52,56,64);
}
QLabel:disabled, QRadioButton:disabled {
    color: rgb(104,109,122);
}

QSpinBox::up-button, QSpinBox::down-button,

QDoubleSpinBox::up-button, QDoubleSpinBox::down-button {

    background: rgb(38,42,50);

    border: none;

    width: 14px;

}

QCheckBox {

    color: rgb(192,206,224);

    spacing: 6px;

}

QLabel {

    color: rgb(192,206,224);

    background: transparent;

}

QListWidget {

    background: rgb(22,24,28);

    color: rgb(210,218,230);

    border: 1px solid rgb(82,86,96);

    border-radius: 3px;

    outline: none;

}

QListWidget::item:selected { background: rgb(50,60,88); }

QListWidget::item:hover    { background: rgb(40,44,54); }

QScrollBar:vertical {

    background: rgb(28,30,36);

    width: 8px;

    border-radius: 4px;

    margin: 0;

}

QScrollBar::handle:vertical {

    background: rgb(90,90,100);

    min-height: 20px;

    border-radius: 4px;

}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }

QToolTip {

    background: rgb(32,36,48);

    color: rgb(220,230,246);

    border: 1px solid rgb(86,122,170);

    border-radius: 5px;

    padding: 8px 12px;

    font-size: 9pt;

}

"""

# ── 主面板 ────────────────────────────────────────────────────────────────────

_STATUS_LABEL = {

    "pending": "待处理", "uploading": "上传中", "submitting": "提交中",

    "polling": "生成中", "downloading": "下载中", "converting": "转换中",

    "importing": "导入中", "done": "完成 ✓", "error": "失败 ✗",

}

class LiClickDialog(QtWidgets.QWidget):

    def __init__(self, parent=None):

        super(LiClickDialog, self).__init__(parent)

        self.setWindowTitle("LiClick 批量图生3D")

        self.setMinimumWidth(420)

        self.setWindowFlags(QtCore.Qt.Window)

        self.scanned = {}

        self.tasks = []

        self.threads = []

        self._layout_x = 0.0

        self._last_settings = {}

        self._build_ui()

        self.setStyleSheet(_STYLE)

    def _on_models_fetched(self, models):

        # 后台拿到最新模型列表后，刷新下拉框（保留当前选择），并写入缓存

        try:

            if not models:

                return

            cur = self.cb_model.currentText()

            self.cb_model.blockSignals(True)

            self.cb_model.clear()

            self.cb_model.addItems(list(models))

            if cur in models:

                self.cb_model.setCurrentText(cur)

            self.cb_model.blockSignals(False)

            _save_cached_models(models)

            self._on_model_changed()

        except Exception:

            pass

    def _mk_row(self, label_text, field):
        """构造一行：固定宽度右对齐标签 + 字段，统一行高，便于整齐排布与整行显隐。"""
        row = QtWidgets.QWidget()
        h = QtWidgets.QHBoxLayout(row)
        h.setContentsMargins(0, 0, 0, 0)
        h.setSpacing(8)
        lbl = QtWidgets.QLabel(label_text)
        lbl.setFixedWidth(66)
        lbl.setAlignment(QtCore.Qt.AlignRight | QtCore.Qt.AlignVCenter)
        h.addWidget(lbl)
        if isinstance(field, QtWidgets.QLayout):
            h.addLayout(field, 1)
        else:
            h.addWidget(field, 1)
        row.setMinimumHeight(28)
        return row

    def _row(self, row, visible):
        """整行显示 / 隐藏（VBox 会自动收掉隐藏行的间距，不留空档）。"""
        try:
            row.setVisible(visible)
        except Exception:
            pass

    def _reject_quad(self, on):
        """四边面效果不佳、暂不开放：点了就弹回三角面，并提示原因。"""
        if on:
            try:
                self.rb_topo_tri.setChecked(True)
                QtWidgets.QToolTip.showText(QtGui.QCursor.pos(), "四边面效果不佳，暂未开放使用")
            except Exception:
                pass

    def _on_model_changed(self, *a):
        # 模型切换：实时把配置区换成「该模型」的一套控件 + 参数范围，和 LiClick 面板一致。
        #   rodin   → 创意描述(必填) + 生成质量 + 模型面数 + 材质配置(PBR/Shaded/无)，单图限制
        #   tripo   → 模型面数 + 拓扑设置 + 生成纹理 + PBR
        #   混元    → 模型面数 + 生成纹理 + PBR
        try:
            model = self.cb_model.currentText()
            ml = (model or "").lower()
            is_rodin = _model_needs_prompt(model)
            is_tripo = ml.startswith("tripo")

            # 按模型显示 / 隐藏各整行
            self._row(self.row_prompt, is_rodin)
            self._row(self.row_quality, is_rodin)
            self._row(self.row_material, is_rodin)
            self._row(self.row_topo, is_tripo)
            self._row(self.row_texpbr, not is_rodin)
            self._row(self.row_face, True)

            # 模型面数：套用该模型的范围 / 默认值
            lo, hi, dv = _face_spec(model)
            try:
                self.sp_face.blockSignals(True)
                self.sp_face.setRange(lo, hi)
                cur = self.sp_face.value()
                if cur < lo or cur > hi:
                    self.sp_face.setValue(dv)
                self.sp_face.blockSignals(False)
            except Exception:
                pass

            # rodin：一次只生成一组（一个物体，可多视角）+ 必填创意描述
            if is_rodin:
                self.lbl_model_hint.setText(
                    "⚠ " + model + "：一次只生成一组（一个物体，可多视角）；下方列表只能勾选一个。必须填创意描述。")
            else:
                self.lbl_model_hint.setText("")
            self._row(self.row_hint, is_rodin)

            # 维护列表勾选：进 rodin 前记下当前多选并收敛成一个；离开 rodin 时恢复之前的多选
            was_rodin = getattr(self, "_was_rodin", False)
            if is_rodin:
                if not was_rodin:
                    self._presaved_checks = self._checked_groups()
                self._enforce_rodin_single_check()
            else:
                if was_rodin:
                    self._restore_checks(getattr(self, "_presaved_checks", None))
            self._was_rodin = is_rodin
        except Exception:
            pass

    def _build_ui(self):

        lay = QtWidgets.QVBoxLayout(self)

        # 自动更新横幅（默认隐藏；静默检查到新版并已下载时显示）
        self.lbl_update = QtWidgets.QLabel("")
        self.lbl_update.setWordWrap(True)
        self.lbl_update.setStyleSheet(
            "background:rgb(40,72,48); color:#9fe6b8; border:1px solid rgb(60,110,72);"
            " border-radius:4px; padding:6px 9px; font-weight:bold;")
        self.lbl_update.hide()
        lay.addWidget(self.lbl_update)
        try:
            self._upd_worker = UpdateWorker(manual=False)
            self._upd_worker.sig_update.connect(self._on_update_result)
            self._upd_worker.start()
        except Exception:
            pass

        # 配置组

        cfg = QtWidgets.QGroupBox("配置")

        cfg.setObjectName("cfg_box")

        self.cfg = cfg   # 生成时锁定 / 暂停时解锁

        cfgv = QtWidgets.QVBoxLayout(cfg)
        cfgv.setSpacing(7)
        cfgv.setContentsMargins(12, 10, 12, 12)

        fld_row = QtWidgets.QHBoxLayout()

        self.ed_folder = QtWidgets.QLineEdit()

        self.ed_folder.setToolTip(

            "包含图片的文件夹路径。\n"

            "支持格式：.jpg / .png / .webp / .bmp / .tif\n\n"

            "命名规则：\n"

            "  龙_前 / 龙_1 → 正面\n"

            "  龙_后 / 龙_2 → 背面\n"

            "  龙_左 / 龙_3 → 左面\n"

            "  龙_右 / 龙_4 → 右面\n"

            "同名前缀的多视角图片会合并为同一个 3D 物体。"

        )

        self.ed_folder.setReadOnly(True)
        self.ed_folder.setPlaceholderText("点右边「选择文件」挑选图片（可多选）")

        self.btn_browse = QtWidgets.QPushButton("选择文件")

        self.btn_browse.setToolTip(
            "选择要生成的图片（可一次多选）。\n"
            "同名前缀的多视角图（前/后/左/右）会自动归为同一个物体。\n"
            "选好后自动扫描，下方按物体分组列出，勾选要生成的即可。")

        self.btn_browse.clicked.connect(self.on_select_files)

        fld_row.addWidget(self.ed_folder)

        fld_row.addWidget(self.btn_browse)

        self._selected_files = []

        self.row_src = self._mk_row("图片源", fld_row)
        cfgv.addWidget(self.row_src)

        self.cb_model = QtWidgets.QComboBox()

        _init_models = _load_cached_models() or list(DEFAULT_GEN_MODELS)

        self.cb_model.addItems(_init_models)

        self.cb_model.setToolTip(

            "选择 AI 生成模型（图生3D / 多视图生3D 可用）。\n\n"

            "每次打开面板会自动从 LiClick 在线获取最新模型，\n"

            "新上线的大模型会自动出现在列表里；\n"

            "联网失败时用本地缓存 / 内置列表。\n\n"

            "  hunyuan-v3.1   混元·有机体细节丰富，速度中等\n"

            "  rodin-gen-2.5  Rodin Gen-2.5，表面细节强\n"

            "  tripo-v3.1     Tripo 通用版，速度较快\n"

            "  tripo-P1       Tripo 智能低模，细节好"

        )

        self.row_model = self._mk_row("选择ai模型", self.cb_model)
        cfgv.addWidget(self.row_model)

        # rodin 单图标注（放在「选择ai模型」下面、「创意描述」上面）
        self.lbl_model_hint = QtWidgets.QLabel("")
        self.lbl_model_hint.setStyleSheet("color:#e0a020; font-size:8pt;")
        self.lbl_model_hint.setWordWrap(True)
        self.row_hint = self._mk_row("", self.lbl_model_hint)
        cfgv.addWidget(self.row_hint)

        # 创意描述（仅 rodin 显示·必填）
        self.ed_prompt = QtWidgets.QLineEdit()
        self.ed_prompt.setPlaceholderText("必填：描述要生成的物体，例如 Q版奶牛，手持蓝色奶瓶")
        self.ed_prompt.setToolTip("创意描述：补充图中结构 / 风格 / 材质 / 用途（内容勿与原图冲突）。")
        self.row_prompt = self._mk_row("创意描述", self.ed_prompt)
        cfgv.addWidget(self.row_prompt)

        # 生成质量（仅 rodin：高 / 极高）
        self.w_quality = QtWidgets.QWidget()
        _ql = QtWidgets.QHBoxLayout(self.w_quality)
        _ql.setContentsMargins(0, 0, 0, 0)
        self.rb_q_high = QtWidgets.QRadioButton("高")
        self.rb_q_extreme = QtWidgets.QRadioButton("极高")
        self.rb_q_high.setChecked(True)
        _ql.addWidget(self.rb_q_high)
        _ql.addSpacing(20)
        _ql.addWidget(self.rb_q_extreme)
        _ql.addStretch()
        self.row_quality = self._mk_row("生成质量", self.w_quality)
        cfgv.addWidget(self.row_quality)

        # 模型面数（所有模型；范围/默认随模型变）
        self.sp_face = DragSpinBox()
        self.sp_face.setRange(500, 2000000)
        self.sp_face.setSingleStep(10000)
        self.sp_face.setValue(1500000)
        self.sp_face.setToolTip("目标面数。不同模型范围不同，切换模型会自动调整。\n拖动数字可快速调整，也可直接输入。")
        self.row_face = self._mk_row("模型面数", self.sp_face)
        cfgv.addWidget(self.row_face)

        # 拓扑设置（仅 tripo：三角面；四边面效果不佳暂不开放，灰显 + 悬停说明）
        self.w_topo = QtWidgets.QWidget()
        _tl = QtWidgets.QHBoxLayout(self.w_topo)
        _tl.setContentsMargins(0, 0, 0, 0)
        self.rb_topo_tri = QtWidgets.QRadioButton("三角面")
        self.rb_topo_quad = QtWidgets.QRadioButton("四边面")
        self.rb_topo_tri.setChecked(True)
        self.rb_topo_quad.setStyleSheet("QRadioButton{color:rgb(120,124,136);}")
        self.rb_topo_quad.setToolTip("四边面效果不佳，暂未开放使用")
        self.rb_topo_quad.toggled.connect(self._reject_quad)
        _tl.addWidget(self.rb_topo_tri)
        _tl.addSpacing(20)
        _tl.addWidget(self.rb_topo_quad)
        _tl.addStretch()
        self.row_topo = self._mk_row("拓扑设置", self.w_topo)
        cfgv.addWidget(self.row_topo)

        # 材质配置（仅 rodin：PBR / Shaded / 无）
        self.w_material = QtWidgets.QWidget()
        _ml = QtWidgets.QHBoxLayout(self.w_material)
        _ml.setContentsMargins(0, 0, 0, 0)
        self.rb_mat_pbr = QtWidgets.QRadioButton("PBR")
        self.rb_mat_shaded = QtWidgets.QRadioButton("Shaded")
        self.rb_mat_none = QtWidgets.QRadioButton("无")
        self.rb_mat_pbr.setChecked(True)
        _ml.addWidget(self.rb_mat_pbr)
        _ml.addSpacing(16)
        _ml.addWidget(self.rb_mat_shaded)
        _ml.addSpacing(16)
        _ml.addWidget(self.rb_mat_none)
        _ml.addStretch()
        self.row_material = self._mk_row("材质配置", self.w_material)
        cfgv.addWidget(self.row_material)

        # 生成纹理 + PBR（仅 混元 / tripo 显示）
        self.w_texpbr = QtWidgets.QWidget()
        sw_row = QtWidgets.QHBoxLayout(self.w_texpbr)
        sw_row.setContentsMargins(0, 0, 0, 0)
        self.chk_tex = StyledCheckBox("生成纹理")
        self.chk_tex.setChecked(True)
        self.chk_tex.setToolTip(
            "为 3D 模型生成颜色贴图。\n"
            "关闭后只输出几何体（灰模），速度更快。")
        self.chk_pbr = StyledCheckBox("PBR")
        self.chk_pbr.setChecked(True)
        self.chk_pbr.setToolTip(
            "同时生成物理渲染材质（金属度、粗糙度、法线贴图）。\n"
            "需先开启「生成纹理」，关闭后 PBR 自动禁用。")
        self.chk_tex.toggled.connect(self.chk_pbr.setEnabled)
        self.chk_tex.setMinimumWidth(90)
        self.chk_pbr.setMinimumWidth(60)
        sw_row.addWidget(self.chk_tex)
        sw_row.addSpacing(30)
        sw_row.addWidget(self.chk_pbr)
        sw_row.addStretch()
        self.row_texpbr = self._mk_row("材质", self.w_texpbr)
        cfgv.addWidget(self.row_texpbr)

        # 后台拉取 LiClick 最新可用模型（不阻塞界面）
        self._model_worker = ModelFetchWorker()
        self._model_worker.sig_models.connect(self._on_models_fetched)
        self._model_worker.start()

        # 模型切换：实时换成该模型的一套 UI + 参数范围
        self.cb_model.currentTextChanged.connect(self._on_model_changed)
        self._on_model_changed()

        # 排列间距（带单位选择，自动换算为场景单位）

        self.sp_gap = DragDoubleSpinBox()

        self.sp_gap.setRange(0.0, 100000.0)

        self.sp_gap.setDecimals(1)

        self.sp_gap.setSingleStep(10.0)

        self.sp_gap.setValue(100.0)

        self.sp_gap.setToolTip(

            "每个导入模型之间的间距。\n"

            "右侧选择单位，程序会自动换算为 Max 当前场景单位。\n\n"

            "拖动数字可快速调整，也可直接点击输入。"

        )

        self.cb_gap_unit = QtWidgets.QComboBox()

        self.cb_gap_unit.addItems(["mm", "cm", "m"])

        self.cb_gap_unit.setCurrentText("cm")

        self.cb_gap_unit.setFixedWidth(52)

        self.cb_gap_unit.setToolTip(

            "间距单位。\n"

            "通过 Max 内置换算转为场景单位，\n"

            "无论场景用哪种系统单位都能得到正确间距。"

        )

        gap_row = QtWidgets.QHBoxLayout()

        gap_row.addWidget(self.sp_gap)

        gap_row.addWidget(self.cb_gap_unit)

        self.row_gap = self._mk_row("排列间距", gap_row)
        cfgv.addWidget(self.row_gap)

        lay.addWidget(cfg)

        # 命名规则说明（表格）

        rule_box = QtWidgets.QGroupBox("命名规则")

        rule_box.setObjectName("rule_box")

        rule_box.setCheckable(True)

        rule_box.setChecked(True)

        rule_box.setToolTip("点标题左侧的勾可折叠 / 展开本栏")

        _rule_outer = QtWidgets.QVBoxLayout(rule_box)

        _rule_outer.setContentsMargins(10, 6, 10, 8)

        self.rule_inner = QtWidgets.QWidget()

        grid = QtWidgets.QGridLayout(self.rule_inner)

        grid.setContentsMargins(0, 0, 0, 0)

        grid.setHorizontalSpacing(24)

        grid.setVerticalSpacing(4)

        def _cell(text, header=False, muted=False):

            w = QtWidgets.QLabel(text)

            if header:

                w.setStyleSheet("font-weight:bold; color: rgb(218,228,244);")

            elif muted:

                w.setStyleSheet("color: rgb(120,130,150);")

            return w

        grid.addWidget(_cell("命名", header=True), 0, 0)

        grid.addWidget(_cell("视角", header=True), 0, 1)

        line = QtWidgets.QFrame()

        line.setFrameShape(QtWidgets.QFrame.HLine)

        line.setStyleSheet("color: rgb(82,86,96);")

        grid.addWidget(line, 1, 0, 1, 2)

        rules = [

            ("龙_前 / 龙_1", "正面"),

            ("龙_后 / 龙_2", "背面"),

            ("龙_左 / 龙_3", "左面"),

            ("龙_右 / 龙_4", "右面"),

            ("其他任意命名", "默认正面（独立物体）"),

        ]

        for i, (a, b) in enumerate(rules, start=2):

            muted = (a == "其他任意命名")

            grid.addWidget(_cell(a, muted=muted), i, 0)

            grid.addWidget(_cell(b, muted=muted), i, 1)

        grid.setColumnStretch(0, 1)

        grid.setColumnStretch(1, 0)

        _rule_outer.addWidget(self.rule_inner)

        rule_box.toggled.connect(self.rule_inner.setVisible)

        lay.addWidget(rule_box)

        # 扫描 + 生成 按钮

        row = QtWidgets.QHBoxLayout()

        self.btn_scan = QtWidgets.QPushButton("扫描文件")

        self.btn_scan.setToolTip(

            "扫描已选的图片（选文件夹 或 选单个图都可以），按命名规则分组显示。\n"

            "不发起网络请求，可随时重新扫描。"

        )

        self.btn_scan.clicked.connect(self.on_scan)

        self.btn_gen = QtWidgets.QPushButton("生成所选")

        self.btn_gen.setToolTip(

            '对列表中「勾选」的物体组批量发起 AI 生成任务。\n每个分组独立线程：上传 → AI 生成 → 下载 → 导入场景。\n（rodin 一次只能勾一个物体）\n\n图片会自动检测尺寸：\n  · 过小（<{}px）→ 等比放大\n  · 过大（>{}px）→ 等比缩小\n  · 文件 >4MB → 缩到 1024px 并转 JPEG\n  · 符合范围 → 直接上传，不做修改'.format(_LICLICK_MIN_PX, _LICLICK_MAX_PX)

        )

        self.btn_gen.clicked.connect(self.on_generate_all)

        self.btn_gen.setEnabled(False)

        row.addWidget(self.btn_scan)

        row.addWidget(self.btn_gen)

        lay.addLayout(row)

        self.lbl_progress = QtWidgets.QLabel("")

        lay.addWidget(self.lbl_progress)

        self.list = CheckListWidget()

        self.list.setMinimumHeight(180)

        self.list.itemChanged.connect(self._on_list_item_changed)

        lay.addWidget(self.list)

        row2 = QtWidgets.QHBoxLayout()

        self.btn_retry = QtWidgets.QPushButton("重试失败任务")

        self.btn_retry.setToolTip("仅重新处理状态为「失败」的任务，成功的任务不受影响。")

        self.btn_retry.clicked.connect(self.on_retry)

        self.btn_pause = QtWidgets.QPushButton("暂停")
        self.btn_pause.setToolTip("暂停：所有任务完成当前步骤后停下，已上传的图 / 已取得的 task_id 不丢失。\n继续：从断点恢复所有任务。")
        self.btn_pause.clicked.connect(self.on_pause_resume)
        self.btn_pause.setEnabled(False)

        self.btn_retry.setEnabled(False)

        self.btn_reset = QtWidgets.QPushButton("重置 / 清空")

        self.btn_reset.setToolTip("清空任务列表和扫描结果，回到初始状态。\n运行中无法重置。")

        self.btn_reset.clicked.connect(self.on_reset)

        row2.addWidget(self.btn_pause)

        row2.addWidget(self.btn_retry)

        row2.addWidget(self.btn_reset)

        lay.addLayout(row2)

        # 底部：检查更新 + 版本号
        urow = QtWidgets.QHBoxLayout()
        self.btn_update = QtWidgets.QPushButton("检查更新")
        self.btn_update.setToolTip("从作者的 Gitee 拉取最新插件；有新版会自动下载，关闭面板重新打开即可生效。")
        self.btn_update.clicked.connect(self.on_check_update)
        urow.addWidget(self.btn_update)
        urow.addStretch()
        _vl = QtWidgets.QLabel("v" + ADDON_VERSION)
        _vl.setStyleSheet("color:rgb(110,116,130); font-size:8pt;")
        urow.addWidget(_vl)
        lay.addLayout(urow)

    def on_check_update(self, *a):
        try:
            self.btn_update.setEnabled(False)
            self.btn_update.setText("检查中…")
            self._upd_worker_m = UpdateWorker(manual=True)
            self._upd_worker_m.sig_update.connect(self._on_update_result)
            self._upd_worker_m.start()
        except Exception:
            try:
                self.btn_update.setEnabled(True)
                self.btn_update.setText("检查更新")
            except Exception:
                pass

    def _on_update_result(self, status, msg, manual):
        b = getattr(self, "btn_update", None)
        if b is not None:
            try:
                b.setEnabled(True)
                b.setText("检查更新")
            except Exception:
                pass
        try:
            if status == "updated":
                self.lbl_update.setText("✓ " + msg)
                self.lbl_update.show()
            if manual:
                QtWidgets.QMessageBox.information(self, "检查更新", msg)
        except Exception:
            pass

    def _clear_selected_files(self):

        self._selected_files = []

    def _checked_groups(self):
        """返回列表中被勾选的物体组名（按显示顺序）。"""
        out = []
        if getattr(self, "list", None) is None:
            return out
        for i in range(self.list.count()):
            it = self.list.item(i)
            if it is None or not (it.flags() & QtCore.Qt.ItemIsUserCheckable):
                continue
            if it.checkState() == QtCore.Qt.Checked:
                n = it.data(QtCore.Qt.UserRole)
                if n:
                    out.append(n)
        return out

    def _set_all_checks(self, checked):
        """把所有可勾选项设为全勾 / 全不勾。"""
        if getattr(self, "list", None) is None:
            return
        st = QtCore.Qt.Checked if checked else QtCore.Qt.Unchecked
        self.list.blockSignals(True)
        try:
            for i in range(self.list.count()):
                it = self.list.item(i)
                if it is not None and (it.flags() & QtCore.Qt.ItemIsUserCheckable):
                    it.setCheckState(st)
        finally:
            self.list.blockSignals(False)

    def _restore_checks(self, names):
        """按给定组名恢复勾选；names 为空则全勾（离开 rodin 时恢复多选用）。"""
        if getattr(self, "list", None) is None:
            return
        if not names:
            self._set_all_checks(True)
            return
        nameset = set(names)
        self.list.blockSignals(True)
        try:
            for i in range(self.list.count()):
                it = self.list.item(i)
                if it is None or not (it.flags() & QtCore.Qt.ItemIsUserCheckable):
                    continue
                it.setCheckState(QtCore.Qt.Checked
                                 if it.data(QtCore.Qt.UserRole) in nameset
                                 else QtCore.Qt.Unchecked)
        finally:
            self.list.blockSignals(False)

    def _enforce_rodin_single_check(self):
        """rodin 下列表最多勾一个：保留第一个勾选项，其余取消。"""
        if not _model_needs_prompt(self.cb_model.currentText()):
            return
        if getattr(self, "list", None) is None:
            return
        seen = False
        self.list.blockSignals(True)
        try:
            for i in range(self.list.count()):
                it = self.list.item(i)
                if it is None or not (it.flags() & QtCore.Qt.ItemIsUserCheckable):
                    continue
                if it.checkState() == QtCore.Qt.Checked:
                    if seen:
                        it.setCheckState(QtCore.Qt.Unchecked)
                    else:
                        seen = True
        finally:
            self.list.blockSignals(False)

    def _on_list_item_changed(self, item):
        """rodin 单选：刚勾上一个 → 自动取消其它（单选框行为）。"""
        try:
            if item is None or item.checkState() != QtCore.Qt.Checked:
                return
            if not _model_needs_prompt(self.cb_model.currentText()):
                return
            self.list.blockSignals(True)
            for i in range(self.list.count()):
                it = self.list.item(i)
                if it is not None and it is not item and (it.flags() & QtCore.Qt.ItemIsUserCheckable):
                    it.setCheckState(QtCore.Qt.Unchecked)
            self.list.blockSignals(False)
        except Exception:
            try:
                self.list.blockSignals(False)
            except Exception:
                pass

    def on_select_files(self):

        files, _ = QtWidgets.QFileDialog.getOpenFileNames(

            self, "选择图片文件（可多选）", "",

            "图片文件 (*.png *.jpg *.jpeg *.webp *.bmp *.tif *.tiff)"

        )

        if files:

            self._selected_files = files

            self.ed_folder.setText("< 已选 {} 张图片 >".format(len(files)))

            self.on_scan()

    def on_scan(self):

        try:

            self._do_scan()

        except Exception as _e:

            import traceback

            QtWidgets.QMessageBox.critical(self, "扫描出错", traceback.format_exc())

    def _do_scan(self):

        if self._selected_files:

            self.scanned = scan_files(self._selected_files)

        else:

            folder = self.ed_folder.text().strip()

            if not folder or not os.path.isdir(folder):

                QtWidgets.QMessageBox.warning(self, "提示", "请先选择文件夹或图片文件")

                return

            self.scanned = scan_folder(folder)

        self.tasks = []

        self.list.clear()

        if not self.scanned:

            self.lbl_progress.setText("未找到图片文件")

            self.btn_gen.setEnabled(False)

            return

        self.lbl_progress.setText('找到 {} 个物体组，勾选要生成的：'.format(len(self.scanned)))

        self.list.blockSignals(True)

        for name, views in self.scanned.items():

            item = QtWidgets.QListWidgetItem('  {}  [{}]'.format(name, ' / '.join(views.keys())))

            item.setFlags(item.flags() | QtCore.Qt.ItemIsUserCheckable)

            item.setData(QtCore.Qt.UserRole, name)

            item.setCheckState(QtCore.Qt.Checked)

            self.list.addItem(item)

        self.list.blockSignals(False)

        self._enforce_rodin_single_check()

        self.btn_gen.setEnabled(True)

    def _is_running(self):

        return any(t["status"] in ("uploading", "submitting", "polling",

                                   "downloading", "converting", "importing")

                   for t in self.tasks)

    def on_generate_all(self):

        if not self.scanned:

            return

        # 按列表里的勾选决定生成哪些物体组
        checked = self._checked_groups()
        if not checked:
            QtWidgets.QMessageBox.warning(self, "提示", "请在下方列表勾选至少一个要生成的物体组。")
            return
        _model = self.cb_model.currentText()
        if _model_needs_prompt(_model):
            if not self.ed_prompt.text().strip():
                QtWidgets.QMessageBox.warning(self, "提示", _model + " 必须填写创意描述。")
                return
            if len(checked) > 1:
                QtWidgets.QMessageBox.warning(self, "提示", _model + " 一次只能生成一组，请只勾选一个物体。")
                return
        groups_to_gen = dict((n, self.scanned[n]) for n in checked if n in self.scanned)

        ready = {}

        for name, views in groups_to_gen.items():

            rv = {}

            for view, path in views.items():

                try:

                    np_, _, _ = resize_for_upload(path)

                    rv[view] = np_

                except Exception:

                    rv[view] = path

            ready[name] = rv

        gap_raw = self.sp_gap.value()

        unit = self.cb_gap_unit.currentText()

        try:

            gap_scene = rt.units.decodeValue('{}{}'.format(gap_raw, unit))

        except Exception:

            gap_scene = gap_raw

        self._last_settings = {

            "model": self.cb_model.currentText(),

            "prompt": self.ed_prompt.text().strip(),

            "gen_tex": self.chk_tex.isChecked(),

            "pbr": self.chk_pbr.isChecked(),

            "face": int(self.sp_face.value()),

            "quality": ("Gen-2.5-Extreme-High" if self.rb_q_extreme.isChecked()
                        else "Gen-2.5-High"),

            "material": ("Shaded" if self.rb_mat_shaded.isChecked()
                         else ("None" if self.rb_mat_none.isChecked() else "PBR")),

            "gap": gap_scene,

        }

        self._layout_x = _compute_start_x(self._last_settings["gap"])

        self.tasks = [{

            "group_name": name, "status": "pending", "message": "等待开始...",

            "fail_step": None, "views": rv, "model_path": None,

        } for name, rv in ready.items()]

        self._refresh_list()

        self._set_busy(True)

        self.threads = []

        for i, (name, rv) in enumerate(ready.items()):

            self._start_worker(i, name, rv)

    def on_retry(self):

        failed = [i for i, t in enumerate(self.tasks) if t["status"] == "error"]

        if not failed:

            return

        if not self._last_settings:

            QtWidgets.QMessageBox.warning(self, "提示", "缺少生成参数，请重新「生成所选」")

            return

        self._layout_x = _compute_start_x(self._last_settings.get("gap", 100.0))

        for i in failed:

            self.tasks[i].update(status="pending", message="等待重试...", fail_step=None)

        self._refresh_list()

        self._set_busy(True)

        for i in failed:

            self._start_worker(i, self.tasks[i]["group_name"], self.tasks[i]["views"])

    def on_pause_resume(self):
        if _pause_event.is_set():        # 运行中 → 暂停
            _pause_event.clear()
            self.btn_pause.setText("继续")
            self._lock_config(False)     # 暂停时解锁配置，可自由调整
        else:                             # 暂停中 → 继续
            _pause_event.set()
            self.btn_pause.setText("暂停")
            self._lock_config(True)      # 继续时重新锁定
        self._refresh_list()

    def _start_worker(self, idx, name, views):

        s = self._last_settings

        w = GenWorker(idx, name, views, s)

        w.sig_progress.connect(self.on_progress)

        w.sig_done.connect(self.on_done)

        w.sig_fail.connect(self.on_fail)

        self.threads.append(w)

        w.start()

    def on_reset(self):

        if self._is_running():

            QtWidgets.QMessageBox.information(self, "提示", "有任务运行中，请等待完成")

            return

        self.scanned = {}

        self.tasks = []

        self.list.clear()

        self.lbl_progress.setText("")

        self.btn_gen.setEnabled(False)

        self.btn_retry.setEnabled(False)

    def on_progress(self, idx, status, msg):

        self.tasks[idx]["status"] = status

        self.tasks[idx]["message"] = msg

        self._refresh_list()

    def on_done(self, idx, model_path, group_name):

        self.tasks[idx]["status"] = "importing"

        self.tasks[idx]["message"] = "导入到 3ds Max..."

        self._refresh_list()

        QtWidgets.QApplication.processEvents()

        try:

            s = self._last_settings

            self._layout_x = _max_import_and_place(

                model_path, group_name, self._layout_x,

                gap=s.get("gap", 100.0),

            )

            self.tasks[idx]["status"] = "done"

            self.tasks[idx]["message"] = '已导入：{}'.format(os.path.basename(model_path))

        except Exception as exc:

            self.tasks[idx]["status"] = "error"

            self.tasks[idx]["fail_step"] = "导入到 3ds Max"

            self.tasks[idx]["message"] = _txt(exc)

        self._after_change()

    def on_fail(self, idx, step, msg):

        self.tasks[idx]["status"] = "error"

        self.tasks[idx]["fail_step"] = step

        self.tasks[idx]["message"] = msg

        self._after_change()

    def _after_change(self):

        self._refresh_list()

        if not self._is_running():

            self._set_busy(False)

            n_err = sum(1 for t in self.tasks if t["status"] == "error")

            self.btn_retry.setEnabled(n_err > 0)

    def _refresh_list(self):

        self.list.clear()

        n_done = sum(1 for t in self.tasks if t["status"] == "done")

        n_err = sum(1 for t in self.tasks if t["status"] == "error")

        n_total = len(self.tasks)

        # 一旦有失败任务就放开「重试失败任务」，不必等全部跑完
        self.btn_retry.setEnabled(n_err > 0)

        if n_total:

            self.lbl_progress.setText(

                '进度：{}/{} 完成'.format(n_done, n_total) + ('，{} 个失败'.format(n_err) if n_err else ""))

        for t in self.tasks:

            st = t["status"]

            if st == "error":

                step = t.get("fail_step") or "未知步骤"

                text = '[失败@{}] {}：{}'.format(step, t['group_name'], t['message'])

            else:

                text = '[{}] {}：{}'.format(_STATUS_LABEL.get(st, st), t['group_name'], t['message'])

            item = QtWidgets.QListWidgetItem(text)

            # 生成阶段只读：去掉默认的可勾选标志，避免点中状态条目时冒出勾选框
            item.setFlags(QtCore.Qt.ItemIsEnabled | QtCore.Qt.ItemIsSelectable)

            if st == "error":

                item.setForeground(QtGui.QBrush(QtGui.QColor("#e06c6c")))

            elif st == "done":

                item.setForeground(QtGui.QBrush(QtGui.QColor("#6cba6c")))

            self.list.addItem(item)

    def closeEvent(self, event):
        _pause_event.set()              # 关闭时放行暂停中的线程，避免卡死
        try:
            super(LiClickDialog, self).closeEvent(event)
        except Exception:
            pass

    def _lock_config(self, locked):
        """锁定 / 解锁配置区（生成时锁、暂停时解锁、跑完恢复）。"""
        try:
            self.cfg.setEnabled(not locked)
        except Exception:
            pass

    def _set_busy(self, busy):
        self.btn_scan.setEnabled(not busy)
        self.btn_gen.setEnabled(not busy and bool(self.scanned))
        self.btn_reset.setEnabled(not busy)
        self.btn_pause.setEnabled(busy)
        self._lock_config(busy)      # 开始生成→锁定；全部跑完→解锁
        # btn_retry 由 _refresh_list 按"是否有失败任务"实时控制，这里不再强制灰显
        if busy:
            _pause_event.set()
        else:
            _pause_event.set()
            self.btn_pause.setText("暂停")

# ── 启动 ─────────────────────────────────────────────────────────────────────

def show_dialog():

    parent = None

    try:

        import qtmax

        parent = qtmax.GetQMaxMainWindow()

    except Exception:

        try:

            import MaxPlus

            parent = MaxPlus.GetQMaxMainWindow()

        except Exception:

            parent = None

    global _liclick_dialog

    try:

        _liclick_dialog.close()

    except Exception:

        pass

    _liclick_dialog = LiClickDialog(parent)

    _liclick_dialog.show()

    return _liclick_dialog

_liclick_dialog = None

show_dialog()
