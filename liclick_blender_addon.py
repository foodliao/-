bl_info = {
    "name": "LiClick 批量图生3D",
    "version": (2, 0, 0),
    "blender": (3, 0, 0),
    "location": "View3D > Sidebar > LiClick",
    "description": "选择图片 → 勾选物体组 → 各 AI 模型参数随选切换 → 批量生成 3D 并自动导入、统一大小排队；含自动更新",
    "category": "Import-Export",
}

import bpy
import subprocess
import json
import threading
import os
import re
import urllib.request
import tempfile
import time
from pathlib import Path
from collections import defaultdict


# ── 命名规则 ──────────────────────────────────────────────────────────────────
# 后缀 _前/_1=正面，_后/_2=背面，_左/_3=左面，_右/_4=右面；
# 同名前缀的多视角图片归入同一物体组，其他任意命名各自独立。
_SUFFIX_TO_VIEW = {
    "_前": "front", "_后": "back", "_左": "left", "_右": "right",
    "_1":  "front", "_2":  "back", "_3":  "left", "_4":  "right",
}
_IMG_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}

# ── 图片缩放（自动适配 LiClick 上传要求）─────────────────────────────────────
_LICLICK_MIN_PX = 512              # 最大边 < 此值时等比放大（太小 AI 细节差）
_LICLICK_MAX_PX = 2048             # 最大边 > 此值时等比缩小
_LICLICK_MAX_FILE_BYTES = 4 * 1024 * 1024  # 4 MB：超限时即使尺寸合格也缩到 1024px 重编码


def _resize_for_upload(image_path: str) -> tuple:
    """
    自动检测并调整图片尺寸与文件体积。必须在主线程调用。
    返回 (上传路径, 是否缩放, 原尺寸str)。
    """
    img = bpy.data.images.load(image_path, check_existing=False)
    try:
        w, h = img.size
        size_str = f"{w}x{h}"
        max_side = max(w, h)

        if max_side < _LICLICK_MIN_PX:
            target = _LICLICK_MIN_PX
        elif max_side > _LICLICK_MAX_PX:
            target = _LICLICK_MAX_PX
        elif os.path.getsize(image_path) > _LICLICK_MAX_FILE_BYTES:
            # 尺寸合格但文件太大，缩到 1024px 重编码（不超过原尺寸，防止误放大）
            target = min(max_side, 1024)
        else:
            return image_path, False, size_str

        scale = target / max_side
        nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
        img.scale(nw, nh)
        base = os.path.splitext(os.path.basename(image_path))[0]
        # 用 JPEG 而非 PNG：同分辨率文件体积小 10-20 倍，彻底规避 413
        tmp = os.path.join(tempfile.gettempdir(), f"liclick_upload_{base}.jpg")
        img.filepath_raw = tmp
        img.file_format = "JPEG"
        img.save()
        return tmp, True, size_str
    finally:
        bpy.data.images.remove(img)


def scan_folder(folder: str) -> dict:
    """
    扫描文件夹，按命名规则分组。
    返回 {group_name: {"front": path, ...}}，已按组名排序。
    同一组同一视角有多张图时，第一张（字母序）优先。
    """
    groups = defaultdict(dict)
    for f in sorted(Path(folder).iterdir()):
        if not f.is_file() or f.suffix.lower() not in _IMG_EXTS:
            continue
        stem = f.stem
        view = "front"
        base = stem
        for sfx, vname in _SUFFIX_TO_VIEW.items():
            if stem.endswith(sfx):
                view = vname
                base = stem[: -len(sfx)]
                break
        if view not in groups[base]:
            groups[base][view] = str(f)
    return dict(sorted(groups.items()))


def scan_files(file_paths: list) -> dict:
    """把一组散图路径按命名规则分组，与 scan_folder 返回相同结构。"""
    groups = defaultdict(dict)
    for fp in file_paths:
        f = Path(fp)
        if not f.is_file() or f.suffix.lower() not in _IMG_EXTS:
            continue
        stem = f.stem
        view = "front"
        base = stem
        for sfx, vname in _SUFFIX_TO_VIEW.items():
            if stem.endswith(sfx):
                view = vname
                base = stem[: -len(sfx)]
                break
        if view not in groups[base]:
            groups[base][view] = str(f)
    return dict(sorted(groups.items()))


# ── 间距换算 ──────────────────────────────────────────────────────────────────
def _gap_to_meters(value: float, unit: str) -> float:
    if unit == "cm":
        return value * 0.01
    if unit == "mm":
        return value * 0.001
    return value  # "m"


# ── 全局状态 ──────────────────────────────────────────────────────────────────
_scanned: dict = {}
_tasks: list = []
_tasks_lock = threading.Lock()
_timer_registered = False
_layout_x = 0.0
_current_gap_m = 0.1     # 当前批次使用的间距（米），由 GenerateAll/RetryFailed 设置
_last_settings = {}
_pause_event = threading.Event()
_pause_event.set()  # set = 运行中，clear = 已暂停


def _get_tasks():
    with _tasks_lock:
        return [dict(t) for t in _tasks]


def _update_task(idx, **kwargs):
    with _tasks_lock:
        if 0 <= idx < len(_tasks):
            _tasks[idx].update(kwargs)


# ── 各模型可调参数（与 LiClick 面板一致）+ 在线拉取最新模型 ───────────────────
DEFAULT_GEN_MODELS = ["hunyuan-v3.1", "rodin-gen-2.5", "tripo-v3.1", "tripo-P1"]
_PROMPT_MODELS = {"rodin-gen-2.5"}
_FACE_SPEC = {
    "hunyuan-v3.1": (10000, 1500000, 1500000),
    "rodin-gen-2.5": (20000, 2000000, 2000000),
    "tripo-v3.1": (500, 2000000, 500000),
    "tripo-P1": (500, 20000, 20000),
}
_online_models = list(DEFAULT_GEN_MODELS)
_enum_cache = []


def _model_needs_prompt(name):
    if not name:
        return False
    return name in _PROMPT_MODELS or name.lower().startswith("rodin")


def _face_spec(name):
    return _FACE_SPEC.get(name, (500, 2000000, 500000))


def _mesh_mode(name):
    m = (name or "").lower()
    if "p1" in m:
        return "smart_low_poly"
    if "tripo" in m:
        return "high_precision"
    return None


def _model_items_cb(self, context):
    """模型下拉项（动态：用在线拉取到的最新列表）。需缓存防 Blender 回收崩溃。"""
    global _enum_cache
    _enum_cache = [(m, m, m) for m in (_online_models or DEFAULT_GEN_MODELS)]
    return _enum_cache


# ===== 自动更新：用户装好后自动从 Gitee 拉最新插件；作者每次只需 push 一份插件文件 =====
ADDON_VERSION = "2.0.0"   # 每次发布新版就改大（如 2.0.1 / 2.1.0）
GITEE_USER = "foodliao"               # ← 你的 Gitee 用户名
GITEE_REPO = "max-toolbox"            # ← 你的 Gitee 仓库名
GITEE_BRANCH = "master"
_UPDATE_REMOTE_PY = "liclick_blender_addon.py"   # 仓库里这份 Blender 插件的文件名
_update_status_msg = ""


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
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def _check_update():
    """拉远端插件 → 比对其内置版本 → 新版就覆盖本插件文件。返回 (status, msg)。"""
    global _update_status_msg
    base = _update_base_url()
    if not base:
        return ("none", "未配置更新源（作者未填 Gitee 地址）")
    try:
        new_code = _fetch_text(base + _UPDATE_REMOTE_PY)
    except Exception as e:
        return ("err", "检查更新失败：%s" % e)
    m = re.search(r'ADDON_VERSION\s*=\s*[\'"]([\d.]+)[\'"]', new_code)
    remote_ver = m.group(1) if m else None
    if (not remote_ver) or ("LICLICK_PT_Main" not in new_code) or (len(new_code) < 4000):
        return ("err", "更新源内容异常，已跳过")
    if _parse_ver(remote_ver) <= _parse_ver(ADDON_VERSION):
        return ("latest", "已是最新版 v" + ADDON_VERSION)
    try:
        dst = os.path.abspath(__file__)
        try:
            import shutil
            shutil.copy2(dst, dst + ".bak")
        except Exception:
            pass
        with open(dst, "w", encoding="utf-8") as f:
            f.write(new_code)
        _update_status_msg = "已更新到 v%s，重启 Blender 即可生效" % remote_ver
        return ("updated", _update_status_msg)
    except Exception as e:
        return ("err", "写入更新失败：%s" % e)


def _silent_update_check():
    def _run():
        try:
            _check_update()
        except Exception:
            pass
    threading.Thread(target=_run, daemon=True).start()


def _fetch_generation_models():
    """从 get-tool 拉最新生成模型 → 更新 _online_models。后台线程调用。"""
    global _online_models, _PROMPT_MODELS
    try:
        out = _run_gateway("get-tool", "--service", "liclick", "--tool", "generate_model_3d")
    except Exception:
        return
    if not out:
        return
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
    need_prompt = set()
    for ln in out.splitlines():
        s = ln.strip()
        mm = re.match(r"^-\s*([A-Za-z][A-Za-z0-9._-]+)[：:]", s)
        if mm and ("prompt" in s) and ("必填" in s):
            need_prompt.add(mm.group(1))
    if need_prompt:
        _PROMPT_MODELS = need_prompt
    if gen:
        _online_models = gen


def _bg_fetch_models():
    threading.Thread(target=_fetch_generation_models, daemon=True).start()


# ── CLI 封装 ──────────────────────────────────────────────────────────────────
def _run_gateway(*args):
    """
    调用 atlas-skillhub gateway CLI。
    Windows 下把输出重定向到临时文件而不用管道，
    避免 Node.js libuv 在进程结束时因管道触发 UV_HANDLE_CLOSING 断言崩溃。
    """
    cmd = ["atlas-skillhub", "gateway"] + list(args)
    uid = f"{os.getpid()}_{int(time.time() * 1e6) % 9999999}"
    out_path = os.path.join(tempfile.gettempdir(), f"lgw_{uid}.txt")

    try:
        if os.name == "nt":
            subprocess.run(
                f'{subprocess.list2cmdline(cmd)} 1>"{out_path}" 2>&1',
                shell=True,
                stdin=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
        else:
            with open(out_path, "w", encoding="utf-8") as fh:
                subprocess.run(cmd, stdin=subprocess.DEVNULL,
                               stdout=fh, stderr=subprocess.STDOUT)

        with open(out_path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    finally:
        try:
            os.unlink(out_path)
        except Exception:
            pass

    clean_lines = [
        l for l in raw.splitlines()
        if "UV_HANDLE_CLOSING" not in l and "Assertion failed" not in l
    ]
    output = "\n".join(clean_lines).strip()

    if not output:
        raise RuntimeError(f"命令无输出。原始内容：{raw[:300]}")
    return output


def _unwrap_gateway(text: str) -> str:
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


def _parse_asset_id(text: str):
    candidates = [text, _unwrap_gateway(text), text.replace('\\"', '"')]
    for s in candidates:
        m = re.search(r'"asset_id"\s*:\s*"([^"]+)"', s)
        if m:
            return m.group(1)
        m = re.search(r'"id"\s*:\s*"([0-9a-f\-]{20,})"', s, re.I)
        if m:
            return m.group(1)
    return None


def _parse_task_id(text: str):
    candidates = [text, _unwrap_gateway(text), text.replace('\\"', '"')]
    for s in candidates:
        for key in ("task_id", "request_id"):
            m = re.search(rf'"{key}"\s*:\s*"([^"]+)"', s)
            if m:
                return m.group(1)
        m = re.search(r'task_id["\s:：，,]+([0-9a-fA-F]{8}-[0-9a-fA-F\-]{20,})', s)
        if m:
            return m.group(1)
        m = re.search(r'\b([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\b', s)
        if m:
            return m.group(1)
    return None


def _parse_model_url(text: str):
    s = text.replace('\\/', '/')
    m = re.search(
        r'https://[^\s"\'<>\\]*?\.(?:glb|fbx|obj|stl|usdz)[^\s"\'<>\\]*',
        s, re.IGNORECASE,
    )
    return m.group(0) if m else None


def _download_model(url: str, dest: str):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/120.0 Safari/537.36",
            "Accept": "*/*",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp, open(dest, "wb") as fh:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            fh.write(chunk)


# ── 可中断 sleep（暂停时提前退出）────────────────────────────────────────────
def _interruptible_sleep(seconds: float):
    deadline = time.time() + seconds
    while time.time() < deadline:
        time.sleep(0.5)
        if not _pause_event.is_set():
            return


# ── 单组后台线程：上传 → 提交 → 轮询 → 下载 ──────────────────────────────────
def _group_worker(idx: int, group_name: str, views: dict, settings: dict):
    model = settings.get("model", "")
    stage = "上传参考图"
    try:
        stage = "上传参考图"
        _update_task(idx, status="uploading", message=f"上传 {len(views)} 张图片...")
        uploaded = {}
        view_items = list(views.items())
        for i, (view, path) in enumerate(view_items, 1):
            if not _pause_event.is_set():
                _update_task(idx, message=f"上传图片 {i}/{len(view_items)}（{view}）[已暂停]")
                _pause_event.wait()
            _update_task(idx, message=f"上传图片 {i}/{len(view_items)}（{view}）")
            asset_id = None
            for _try in range(3):     # 瞬时失败重试（多组并行时常见）
                try:
                    out = _run_gateway(
                        "call-tool", "--service", "liclick", "--tool", "upload_asset",
                        "--file", f"file_path={path}",
                    )
                    asset_id = _parse_asset_id(out)
                except Exception:
                    asset_id = None
                if asset_id:
                    break
                _update_task(idx, message=f"上传重试（{view} 第 {_try + 2} 次）")
                _interruptible_sleep(3)
            if not asset_id:
                raise RuntimeError(f"上传 {view} 图失败（重试 3 次仍未返回 asset_id）")
            uploaded[view] = f"asset:{asset_id}"

        stage = "提交生成任务"
        if not _pause_event.is_set():
            _update_task(idx, status="submitting", message="等待继续后提交 [已暂停]")
            _pause_event.wait()
        _update_task(idx, status="submitting", message="提交生成任务...")
        args_dict = {"request_type": "generation", "model": model}
        args_dict.update(uploaded)
        # 按模型组装该模型支持的参数（与 LiClick 面板一致）
        ml = (model or "").lower()
        ep = {}
        face = settings.get("face")
        if face:
            ep["face_count"] = int(face)
        if ml.startswith("rodin"):
            if settings.get("prompt"):
                args_dict["prompt"] = settings["prompt"]
            ep["tier"] = settings.get("quality", "Gen-2.5-High")
            ep["material"] = settings.get("material", "PBR")
        else:
            gt = bool(settings.get("generate_texture", True))
            ep["generate_texture"] = gt
            ep["enable_pbr"] = bool(settings.get("enable_pbr", True)) if gt else False
            if ml.startswith("tripo"):
                mm = _mesh_mode(model)
                if mm:
                    ep["mesh_mode"] = mm
                ep["polygon_type"] = "triangle"
        args_dict["extra_params"] = ep
        # ensure_ascii=True：中文创意描述转 \uXXXX，命令行纯 ASCII，避免 subprocess 编码问题
        out = _run_gateway(
            "call-tool", "--service", "liclick", "--tool", "generate_model_3d",
            "--args", json.dumps(args_dict),
        )
        task_id = _parse_task_id(out)
        if not task_id:
            raise RuntimeError(f"未获取到 task_id。响应：{out[:500]}")
        stage = "等待生成（轮询）"
        _update_task(idx, status="polling", message=f"生成中 ({task_id[:8]}…)", task_id=task_id)

        for attempt in range(80):
            _interruptible_sleep(15)
            if not _pause_event.is_set():
                _update_task(idx, message=f"已暂停（task: {task_id[:8]}…）")
                _pause_event.wait()
            _update_task(idx, message=f"等待完成（第 {attempt + 1} 次轮询）")
            out = None
            for _q in range(3):     # 同一轮快速重试，扛瞬时空响应
                try:
                    out = _run_gateway(
                        "call-tool", "--service", "liclick", "--tool", "get_task_status",
                        f"task_id={task_id}", "task_type=model_3d",
                    )
                    break
                except Exception:
                    out = None
                    _interruptible_sleep(3)
            if not out:
                _update_task(idx, message=f"查询无响应，稍后重试（第 {attempt + 1} 次）")
                continue

            if "完成" in out or "Finished" in out:
                url = _parse_model_url(out)

                def _write_debug():
                    try:
                        logp = os.path.join(os.path.expanduser("~"), "Desktop",
                                            f"liclick_debug_{group_name}.txt")
                        with open(logp, "w", encoding="utf-8") as lf:
                            lf.write("=== 提取出的 URL ===\n")
                            lf.write(str(url) + "\n\n=== 完整响应 ===\n")
                            lf.write(out)
                    except Exception:
                        pass

                if not url:
                    _write_debug()
                    raise RuntimeError("任务完成但未找到模型 URL（详情见桌面日志）")

                stage = "下载模型"
                _update_task(idx, status="downloading", message="下载模型文件...")
                em = re.search(r'\.(glb|fbx|obj|stl|usdz)', url, re.I)
                ext = em.group(0) if em else ".glb"
                safe = re.sub(r'[\\/:*?"<>|]', '_', group_name).strip() or "model"
                out_dir = os.path.join(os.path.expanduser("~"), "Desktop", "LiClick_Models")
                os.makedirs(out_dir, exist_ok=True)
                dest = os.path.join(out_dir, f"{safe}{ext}")
                try:
                    _download_model(url, dest)
                except Exception as dl_exc:
                    _write_debug()
                    raise RuntimeError(f"下载失败({dl_exc})。详情见桌面 liclick_debug_{group_name}.txt")
                _update_task(idx, status="ready", message=f"已下载到桌面：{safe}{ext}",
                             model_path=dest)
                return

            if "Failed" in out or "失败" in out:
                inner = _unwrap_gateway(out)
                em = re.search(r'"err_msg"\s*:\s*"([^"]+)"', inner) or \
                     re.search(r'"err_msg"\s*:\s*"([^"]+)"', out)
                raise RuntimeError(em.group(1) if em else "任务失败（无详情）")

        stage = "等待生成（轮询）"
        raise RuntimeError("超时（20 分钟内未完成）")

    except Exception as exc:
        _update_task(idx, status="error", message=str(exc), fail_step=stage)


# ── 主线程定时器：刷新 UI + 触发导入 ─────────────────────────────────────────
def _world_bbox(obj):
    from mathutils import Vector
    cs = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in cs]; ys = [c.y for c in cs]; zs = [c.z for c in cs]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def _compute_start_x(gap_m: float = 0.1):
    """扫描场景已有 mesh 的最右边界，返回新一批模型的起始 x。"""
    max_x = None
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        try:
            mx = _world_bbox(o)[1]
            max_x = mx if max_x is None else max(max_x, mx)
        except Exception:
            pass
    return 0.0 if max_x is None else max_x + gap_m


_IMPORT_TARGET_M = 1.0   # 导入后统一把每个模型缩放到「最大边≈此值(米)」


def _do_import(filepath: str, name: str = "", gap_m: float = 0.1):
    global _layout_x
    ext = os.path.splitext(filepath)[1].lower()
    before = set(bpy.data.objects)

    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=filepath)
    elif ext == ".obj":
        try:
            bpy.ops.wm.obj_import(filepath=filepath)          # Blender 4.0+
        except AttributeError:
            bpy.ops.import_scene.obj(filepath=filepath)       # Blender 3.x
    elif ext == ".stl":
        try:
            bpy.ops.wm.stl_import(filepath=filepath)          # Blender 4.0+
        except AttributeError:
            bpy.ops.import_mesh.stl(filepath=filepath)        # Blender 3.x
    else:
        raise RuntimeError(f"不支持的格式：{ext}")

    new_objs = [o for o in bpy.data.objects if o not in before]
    if not new_objs:
        return

    for o in bpy.context.selected_objects:
        o.select_set(False)

    for o in new_objs:
        o.select_set(True)
    if new_objs:
        bpy.context.view_layer.objects.active = new_objs[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")

    meshes = [o for o in new_objs if o.type == "MESH"]
    empties = [o for o in new_objs if o.type == "EMPTY"]
    for e in empties:
        bpy.data.objects.remove(e, do_unlink=True)

    if not meshes:
        return

    for o in bpy.context.selected_objects:
        o.select_set(False)
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    if name:
        obj.name = name

    # 统一大小：把每个模型缩放到「最大边 ≈ _IMPORT_TARGET_M」，避免各模型大小不一
    try:
        bx0, bx1, by0, by1, bz0, bz1 = _world_bbox(obj)
        maxdim = max(bx1 - bx0, by1 - by0, bz1 - bz0)
        if maxdim > 1e-5:
            f = _IMPORT_TARGET_M / maxdim
            obj.scale = (obj.scale[0] * f, obj.scale[1] * f, obj.scale[2] * f)
            bpy.context.view_layer.update()
            for o in bpy.context.selected_objects:
                o.select_set(False)
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    except Exception:
        pass

    from mathutils import Vector
    min_x, max_x, min_y, max_y, min_z, max_z = _world_bbox(obj)
    bottom_center = Vector(((min_x + max_x) / 2.0, (min_y + max_y) / 2.0, min_z))
    scene = bpy.context.scene
    saved_cursor = tuple(scene.cursor.location)
    scene.cursor.location = bottom_center
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    scene.cursor.location = saved_cursor

    width = max_x - min_x
    obj.location = (_layout_x + width / 2.0, 0.0, 0.0)
    _layout_x += width + max(gap_m, 0.001)


def _timer_callback():
    global _timer_registered

    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                area.tag_redraw()

    tasks = _get_tasks()
    any_active = False

    for i, task in enumerate(tasks):
        st = task["status"]
        if st in ("uploading", "submitting", "polling", "downloading"):
            any_active = True
        elif st == "ready" and task.get("model_path"):
            any_active = True
            try:
                _do_import(task["model_path"], task["group_name"], _current_gap_m)
                _update_task(i, status="done",
                             message=f"已导入：{os.path.basename(task['model_path'])}")
            except Exception as exc:
                _update_task(i, status="error", message=str(exc),
                             fail_step="导入到 Blender")

    if any_active:
        return 1.0

    _timer_registered = False
    return None


# ── 属性 ─────────────────────────────────────────────────────────────────────
class LiClickGroup(bpy.types.PropertyGroup):
    name: bpy.props.StringProperty()
    use: bpy.props.BoolProperty(name="", default=True, description="勾选 = 本次生成这一组")


def _on_model_update(self, context):
    try:
        self.face_count = _face_spec(self.model)[2]
        if _model_needs_prompt(self.model):     # 切到 rodin：只保留第一个勾选
            seen = False
            for g in self.groups:
                if g.use:
                    if seen:
                        g.use = False
                    else:
                        seen = True
    except Exception:
        pass


class LiClickProps(bpy.types.PropertyGroup):
    model: bpy.props.EnumProperty(
        name="选择 AI 模型",
        description="选不同模型，下方参数会随之变化（与 LiClick 面板一致）",
        items=_model_items_cb,
        update=_on_model_update,
    )
    prompt: bpy.props.StringProperty(
        name="创意描述",
        description="rodin 必填：描述要生成的物体，例如 Q版奶牛，手持蓝色奶瓶",
        default="",
    )
    quality: bpy.props.EnumProperty(
        name="生成质量",
        items=[("Gen-2.5-High", "高", "高"),
               ("Gen-2.5-Extreme-High", "极高", "更强调表面细节")],
        default="Gen-2.5-High",
    )
    material: bpy.props.EnumProperty(
        name="材质配置",
        items=[("PBR", "PBR", "物理渲染材质"),
               ("Shaded", "Shaded", "带光照着色"),
               ("None", "无", "仅几何，无材质")],
        default="PBR",
    )
    face_count: bpy.props.IntProperty(
        name="模型面数",
        description="目标面数；切换模型会自动取该模型的默认值",
        default=1500000, min=500, max=2000000,
    )
    generate_texture: bpy.props.BoolProperty(
        name="生成纹理",
        description="是否为模型生成纹理贴图；关闭后只有几何、PBR 不可用",
        default=True,
    )
    enable_pbr: bpy.props.BoolProperty(
        name="PBR",
        description="是否启用 PBR 材质；需先开启「生成纹理」",
        default=True,
    )
    gap_value: bpy.props.FloatProperty(
        name="排列间距",
        description="导入模型之间的间距（右侧选择单位）",
        default=10.0, min=0.0, max=100000.0, step=10,
    )
    gap_unit: bpy.props.EnumProperty(
        name="间距单位",
        items=[("m", "m", "米"), ("cm", "cm", "厘米"), ("mm", "mm", "毫米")],
        default="cm",
    )
    show_rules: bpy.props.BoolProperty(name="命名规则（示例）", default=False)
    groups: bpy.props.CollectionProperty(type=LiClickGroup)
    group_index: bpy.props.IntProperty(default=0)


# ── Operator：扫描文件夹 ───────────────────────────────────────────────────────
def _rebuild_groups(props):
    """按全局 _scanned 重建勾选列表；rodin 默认只勾第一个，其它默认全勾。"""
    props.groups.clear()
    is_rodin = _model_needs_prompt(props.model)
    first = True
    for name in _scanned.keys():
        g = props.groups.add()
        g.name = name
        g.use = (first if is_rodin else True)
        first = False


def _checked_group_names(props):
    return [g.name for g in props.groups if g.use and g.name in _scanned]


class LICLICK_UL_groups(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        row = layout.row(align=True)
        row.prop(item, "use", text="")
        row.label(text=item.name)


class LICLICK_OT_SelectFiles(bpy.types.Operator):
    bl_idname = "liclick.select_files"
    bl_label = "选择文件"
    bl_description = "选择参考图片（可多选）；同名前缀的多视角图自动归为一个物体，选完自动扫描分组"
    directory: bpy.props.StringProperty(subtype="DIR_PATH")
    files: bpy.props.CollectionProperty(type=bpy.types.OperatorFileListElement)
    filter_glob: bpy.props.StringProperty(
        default="*.png;*.jpg;*.jpeg;*.webp;*.bmp;*.tif;*.tiff", options={"HIDDEN"})

    def invoke(self, context, event):
        context.window_manager.fileselect_add(self)
        return {"RUNNING_MODAL"}

    def execute(self, context):
        global _scanned
        paths = [os.path.join(self.directory, f.name) for f in self.files if f.name]
        paths = [p for p in paths if os.path.isfile(p)]
        if not paths:
            self.report({"WARNING"}, "未选择图片")
            return {"CANCELLED"}
        _scanned = scan_files(paths)
        _rebuild_groups(context.scene.liclick_props)
        self.report({"INFO"}, f"已选 {len(paths)} 张，分成 {len(_scanned)} 组，勾选要生成的")
        return {"FINISHED"}


class LICLICK_OT_GroupsSet(bpy.types.Operator):
    bl_idname = "liclick.groups_set"
    bl_label = "全选/全不选"
    use: bpy.props.BoolProperty(default=True)

    def execute(self, context):
        props = context.scene.liclick_props
        is_rodin = _model_needs_prompt(props.model)
        first = True
        for g in props.groups:
            if not self.use:
                g.use = False
            elif is_rodin:
                g.use = first    # rodin 一次只能一组
            else:
                g.use = True
            first = False
        return {"FINISHED"}


class LICLICK_OT_CheckUpdate(bpy.types.Operator):
    bl_idname = "liclick.check_update"
    bl_label = "检查更新"
    bl_description = "从作者的 Gitee 拉取最新插件；有新版自动下载，重启 Blender 生效"

    def execute(self, context):
        st, msg = _check_update()
        self.report({"INFO"} if st in ("updated", "latest") else {"WARNING"}, msg)
        return {"FINISHED"}


# ── Operator：生成所选 ────────────────────────────────────────────────────────
class LICLICK_OT_GenerateAll(bpy.types.Operator):
    bl_idname = "liclick.generate_all"
    bl_label = "生成所选"
    bl_description = (
        "对列表中「勾选」的物体组批量发起 AI 生成任务。\n"
        "每个分组独立线程：上传 → AI 生成 → 下载 → 导入场景。\n"
        "（rodin 一次只能勾一个物体）"
    )

    def execute(self, context):
        global _tasks, _timer_registered, _layout_x, _last_settings, _current_gap_m
        _pause_event.set()
        if not _scanned:
            self.report({"ERROR"}, "请先「选择文件」")
            return {"CANCELLED"}

        props = context.scene.liclick_props
        checked = _checked_group_names(props)
        if not checked:
            self.report({"ERROR"}, "请在列表里勾选至少一个要生成的物体组")
            return {"CANCELLED"}
        if _model_needs_prompt(props.model):
            if not props.prompt.strip():
                self.report({"ERROR"}, props.model + " 必须填写创意描述")
                return {"CANCELLED"}
            if len(checked) > 1:
                self.report({"ERROR"}, props.model + " 一次只能生成一组，请只勾选一个物体")
                return {"CANCELLED"}

        gap_m = _gap_to_meters(props.gap_value, props.gap_unit)
        _current_gap_m = gap_m
        _layout_x = _compute_start_x(gap_m)
        _last_settings = {
            "model": props.model,
            "generate_texture": props.generate_texture,
            "enable_pbr": props.enable_pbr,
            "prompt": props.prompt.strip(),
            "quality": props.quality,
            "material": props.material,
            "face": int(props.face_count),
            "gap_m": gap_m,
        }

        groups_to_gen = {n: _scanned[n] for n in checked if n in _scanned}
        resize_log = []
        ready_groups = {}
        for name, views in groups_to_gen.items():
            ready_views = {}
            for view, path in views.items():
                try:
                    new_path, resized, size_str = _resize_for_upload(path)
                    ready_views[view] = new_path
                    if resized:
                        resize_log.append(f"{os.path.basename(path)} ({size_str})")
                except Exception:
                    ready_views[view] = path
            ready_groups[name] = ready_views

        if resize_log:
            self.report({"INFO"}, f"已调整 {len(resize_log)} 张图片尺寸：{', '.join(resize_log[:3])}"
                        + ("…" if len(resize_log) > 3 else ""))

        with _tasks_lock:
            _tasks = [
                {"group_name": name, "status": "pending", "message": "等待开始...",
                 "task_id": None, "model_path": None, "fail_step": None, "views": dict(views)}
                for name, views in ready_groups.items()
            ]

        for i, (name, views) in enumerate(ready_groups.items()):
            threading.Thread(
                target=_group_worker,
                args=(i, name, views, dict(_last_settings)),
                daemon=True,
            ).start()

        if not _timer_registered:
            bpy.app.timers.register(_timer_callback, first_interval=1.0)
            _timer_registered = True

        return {"FINISHED"}


# ── Operator：重置 ────────────────────────────────────────────────────────────
class LICLICK_OT_Reset(bpy.types.Operator):
    bl_idname = "liclick.reset"
    bl_label = "重置 / 清空"
    bl_description = "清除扫描结果和任务列表，回到初始状态"

    def execute(self, context):
        global _scanned, _tasks
        _scanned = {}
        _pause_event.set()  # 释放暂停中的线程，让其自然结束
        with _tasks_lock:
            _tasks = []
        return {"FINISHED"}


# ── Operator：重试失败任务 ────────────────────────────────────────────────────
class LICLICK_OT_RetryFailed(bpy.types.Operator):
    bl_idname = "liclick.retry_failed"
    bl_label = "重试失败任务"
    bl_description = "只重新提交标记为失败的任务，已成功的不受影响，新模型续排在旁边"

    def execute(self, context):
        global _timer_registered, _layout_x, _current_gap_m
        _pause_event.set()
        with _tasks_lock:
            failed_idx = [i for i, t in enumerate(_tasks) if t["status"] == "error"]
            snapshot = [dict(t) for t in _tasks]
        if not failed_idx:
            self.report({"INFO"}, "没有失败的任务")
            return {"CANCELLED"}
        if not _last_settings:
            self.report({"ERROR"}, "缺少生成参数，请重新「生成所选」")
            return {"CANCELLED"}

        gap_m = _last_settings.get("gap_m", _current_gap_m)
        _current_gap_m = gap_m
        _layout_x = _compute_start_x(gap_m)

        with _tasks_lock:
            for i in failed_idx:
                _tasks[i].update(status="pending", message="等待重试...",
                                 fail_step=None, task_id=None, model_path=None)

        for i in failed_idx:
            t = snapshot[i]
            threading.Thread(
                target=_group_worker,
                args=(i, t["group_name"], t["views"], dict(_last_settings)),
                daemon=True,
            ).start()

        if not _timer_registered:
            bpy.app.timers.register(_timer_callback, first_interval=1.0)
            _timer_registered = True

        self.report({"INFO"}, f"正在重试 {len(failed_idx)} 个失败任务")
        return {"FINISHED"}


# ── Operator：暂停 / 继续 ────────────────────────────────────────────────────
class LICLICK_OT_PauseResume(bpy.types.Operator):
    bl_idname = "liclick.pause_resume"
    bl_label = "暂停 / 继续"
    bl_description = (
        "暂停：所有任务完成当前步骤后停下，已获取的 task_id 保留不丢失。\n"
        "继续：从断点恢复所有任务。"
    )

    def execute(self, context):
        if _pause_event.is_set():
            _pause_event.clear()
        else:
            _pause_event.set()
        for window in bpy.context.window_manager.windows:
            for area in window.screen.areas:
                if area.type == "VIEW_3D":
                    area.tag_redraw()
        return {"FINISHED"}


# ── Panel ─────────────────────────────────────────────────────────────────────
_STATUS_LABEL = {
    "pending":     "待处理",
    "uploading":   "上传中",
    "submitting":  "提交中",
    "polling":     "生成中",
    "downloading": "下载中",
    "ready":       "导入中",
    "done":        "完成  ✓",
    "error":       "错误  ✗",
}


class LICLICK_PT_Main(bpy.types.Panel):
    bl_label = "LiClick 批量图生3D"
    bl_idname = "LICLICK_PT_Main"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "LiClick"

    def draw(self, context):
        layout = self.layout
        props = context.scene.liclick_props
        tasks = _get_tasks()
        is_running = any(
            t["status"] in ("uploading", "submitting", "polling", "downloading", "ready")
            for t in tasks
        )

        # ── 自动更新横幅 ──
        if _update_status_msg:
            layout.box().label(text="✓ " + _update_status_msg, icon="FILE_REFRESH")

        # ── 配置区（生成时整体锁定）──
        cfg = layout.box()
        cfg.enabled = not is_running
        cfg.label(text="配置")
        # 图片源：选择文件（可多选）
        src = cfg.row(align=True)
        src.operator("liclick.select_files", icon="FILE_FOLDER")
        if _scanned:
            src.label(text=f"已分 {len(_scanned)} 组")
        # 选择 AI 模型 + 随模型变化的参数
        cfg.prop(props, "model", text="模型")
        is_rodin = _model_needs_prompt(props.model)
        is_tripo = props.model.lower().startswith("tripo")
        if is_rodin:
            cfg.prop(props, "prompt", text="创意描述")
            cfg.prop(props, "quality", text="生成质量")
        cfg.prop(props, "face_count", text="模型面数")
        if is_tripo:
            trow = cfg.row(align=True)
            trow.label(text="拓扑设置：")
            trow.label(text="三角面")
        if is_rodin:
            cfg.prop(props, "material", text="材质配置")
        else:
            tex_row = cfg.row(align=True)
            tex_row.prop(props, "generate_texture", toggle=True)
            pbr_sub = tex_row.row(align=True)
            pbr_sub.enabled = props.generate_texture
            pbr_sub.prop(props, "enable_pbr", toggle=True)
        if is_rodin:
            cfg.label(text="rodin 一次只生成一组，下方只能勾一个", icon="ERROR")
        # 排列间距
        gap_row = cfg.row(align=True)
        gap_row.label(text="排列间距")
        gap_row.prop(props, "gap_value", text="")
        gap_row.prop(props, "gap_unit", text="")

        # ── 命名规则说明（可折叠）──
        layout.separator(factor=0.2)
        rule = layout.box()
        rule.prop(props, "show_rules",
                  icon="TRIA_DOWN" if props.show_rules else "TRIA_RIGHT",
                  emboss=False)
        if props.show_rules:
            sub = rule.column()
            sub.scale_y = 0.75
            sub.label(text="  龙_前 / 龙_1  →  正面（front）")
            sub.label(text="  龙_后 / 龙_2  →  背面（back）")
            sub.label(text="  龙_左 / 龙_3  →  左面（left）")
            sub.label(text="  龙_右 / 龙_4  →  右面（right）")
            sub.label(text="  其他任意命名  →  各自独立，默认正面")

        # ── 勾选要生成哪些组 ──
        if props.groups:
            gbox = layout.box()
            gbox.enabled = not is_running
            hdr = gbox.row(align=True)
            hdr.label(text="勾选要生成的组：")
            hdr.operator("liclick.groups_set", text="全选").use = True
            hdr.operator("liclick.groups_set", text="全不选").use = False
            gbox.template_list("LICLICK_UL_groups", "", props, "groups",
                               props, "group_index", rows=4)

        layout.separator(factor=0.2)

        # ── 生成所选 按钮 ──
        btn_row = layout.row(align=True)
        btn_row.enabled = not is_running
        btn_row.scale_y = 1.3
        n_sel = len(_checked_group_names(props)) if props.groups else 0
        gen_text = f"生成所选（{n_sel} 组）" if n_sel else "生成所选"
        btn_row.operator("liclick.generate_all", text=gen_text)

        # ── 任务列表 ──
        if tasks:
            _is_paused = not _pause_event.is_set()
            n_done  = sum(1 for t in tasks if t["status"] == "done")
            n_err   = sum(1 for t in tasks if t["status"] == "error")
            n_total = len(tasks)

            layout.label(
                text=f"进度：{n_done}/{n_total} 完成" +
                     ("（已暂停）" if _is_paused else "") +
                     (f"，{n_err} 个失败" if n_err else ""),
            )

            for task in tasks:
                st = task["status"]
                row = layout.row(align=True)
                row.scale_y = 0.85
                if st == "error":
                    step = task.get("fail_step") or "未知步骤"
                    row.alert = True
                    row.label(text=f"[失败@{step}] {task['group_name']}：{task['message']}")
                else:
                    row.label(text=f"[{_STATUS_LABEL.get(st, st)}] {task['group_name']}：{task['message']}")

            layout.separator(factor=0.3)
            btn2 = layout.row(align=True)
            btn2.scale_y = 1.2
            if is_running or _is_paused:
                if _is_paused:
                    resume_sub = btn2.row(align=True)
                    resume_sub.alert = True
                    resume_sub.operator("liclick.pause_resume", text="继续")
                    btn2.operator("liclick.reset", text="重置 / 清空")
                else:
                    btn2.operator("liclick.pause_resume", text="暂停")
            else:
                if n_err:
                    retry_sub = btn2.row(align=True)
                    retry_sub.alert = True
                    retry_sub.operator("liclick.retry_failed",
                                       text=f"重试失败任务（{n_err} 个）")
                btn2.operator("liclick.reset", text="重置 / 清空")

        elif _scanned:
            layout.label(text=f"找到 {len(_scanned)} 个物体组：")
            for name, views in list(_scanned.items())[:8]:
                row = layout.row()
                row.scale_y = 0.8
                row.label(text=f"  {name}  [{' / '.join(views.keys())}]")
            if len(_scanned) > 8:
                layout.label(text=f"  …以及另外 {len(_scanned) - 8} 组")

        # ── 底部：检查更新 + 版本号 ──
        layout.separator(factor=0.3)
        urow = layout.row(align=True)
        urow.operator("liclick.check_update", text="检查更新", icon="FILE_REFRESH")
        urow.label(text="v" + ADDON_VERSION)


# ── 注册 / 注销 ───────────────────────────────────────────────────────────────
_CLASSES = (
    LiClickGroup,
    LiClickProps,
    LICLICK_UL_groups,
    LICLICK_OT_SelectFiles,
    LICLICK_OT_GroupsSet,
    LICLICK_OT_GenerateAll,
    LICLICK_OT_Reset,
    LICLICK_OT_RetryFailed,
    LICLICK_OT_PauseResume,
    LICLICK_OT_CheckUpdate,
    LICLICK_PT_Main,
)


def register():
    for cls in _CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.liclick_props = bpy.props.PointerProperty(type=LiClickProps)
    try:
        _silent_update_check()   # 开机静默检查更新
        _bg_fetch_models()       # 后台拉取最新模型列表
    except Exception:
        pass


def unregister():
    global _timer_registered
    _timer_registered = False
    for cls in reversed(_CLASSES):
        bpy.utils.unregister_class(cls)
    del bpy.types.Scene.liclick_props


if __name__ == "__main__":
    register()
