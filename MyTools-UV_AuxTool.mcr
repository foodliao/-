
macroScript UV_AuxTool
category:"AAA我的工具 (MyTools)"
buttonText:"UV辅助工具"
toolTip:"UV精度调整 + Rizom UV桥接工具"
--@@ICONNAME@@
(
on execute do
(

global TDT_MainTool

try(destroyDialog TDT_MainTool)catch()

global TDT_RB_srcObjs  = #()
global TDT_RB_baseTime = undefined

-- ============================================================
--  版本兼容工具
-- ============================================================

-- 兼容所有版本的 makeDir
global TDT_MakeDir
fn TDT_MakeDir d =
(
    try( makeDir d all:true )catch( try( makeDir d )catch() )
)

-- 获取当前脚本所在目录（兼容各版本）
global TDT_ScriptDir
fn TDT_ScriptDir =
(
    local d = ""
    try( d = getFilenamePath (getThisScriptFilename()) )catch()
    -- getThisScriptFilename 在老版本或某些运行方式下可能失败，回退到空串
    d
)

-- 获取 Unwrap_UVW 修改器的可用接口（Max 各版本接口名不同）
global TDT_GetUnwrapIF
fn TDT_GetUnwrapIF um =
(
    local uwi = undefined
    try( if um.unwrap6 != undefined do uwi = um.unwrap6 )catch()
    if uwi == undefined do try( if um.unwrap5 != undefined do uwi = um.unwrap5 )catch()
    if uwi == undefined do try( if um.unwrap4 != undefined do uwi = um.unwrap4 )catch()
    if uwi == undefined do try( if um.unwrap3 != undefined do uwi = um.unwrap3 )catch()
    if uwi == undefined do try( if um.unwrap2 != undefined do uwi = um.unwrap2 )catch()
    if uwi == undefined do try( if um.unwrap  != undefined do uwi = um.unwrap  )catch()
    uwi
)

-- ============================================================
--  贴图密度 计算与缩放
-- ============================================================

global TDT_TriArea3
fn TDT_TriArea3 p1 p2 p3 =
(
    (length (cross (p2 - p1) (p3 - p1))) * 0.5
)

global TDT_TriArea2
fn TDT_TriArea2 uv1 uv2 uv3 =
(
    abs(((uv2.x - uv1.x) * (uv3.y - uv1.y)) - ((uv2.y - uv1.y) * (uv3.x - uv1.x))) * 0.5
)

global TDT_GetMapSize
fn TDT_GetMapSize index =
(
    case index of
    (
        1: 256
        2: 512
        3: 1024
        4: 2048
        5: 4096
        6: 8192
        default: 1024
    )
)

global TDT_CalcTexelDensity
fn TDT_CalcTexelDensity objs mapSize mapChannel =
(
    local totalWorldArea = 0.0
    local totalUVArea = 0.0

    for obj in objs where isValidNode obj do
    (
        local msh = undefined
        try( msh = snapshotAsMesh obj )catch( msh = undefined )

        if msh != undefined do
        (
            try
            (
                if meshop.getMapSupport msh mapChannel then
                (
                    local faceCount = msh.numfaces
                    for f = 1 to faceCount do
                    (
                        local faceVerts = getFace msh f
                        local p1 = (getVert msh faceVerts.x) * obj.objectTransform
                        local p2 = (getVert msh faceVerts.y) * obj.objectTransform
                        local p3 = (getVert msh faceVerts.z) * obj.objectTransform

                        local mapFace = meshop.getMapFace msh mapChannel f
                        local uv1 = meshop.getMapVert msh mapChannel mapFace.x
                        local uv2 = meshop.getMapVert msh mapChannel mapFace.y
                        local uv3 = meshop.getMapVert msh mapChannel mapFace.z

                        totalWorldArea += (TDT_TriArea3 p1 p2 p3)
                        totalUVArea   += (TDT_TriArea2 uv1 uv2 uv3)
                    )
                )
            )
            catch ()
            try( free msh )catch()
        )
    )

    if totalWorldArea <= 0.0 or totalUVArea <= 0.0 then 0.0
    else
    (
        local _suPerM = 1.0
        try ( _suPerM = units.decodeValue "1m" ) catch ()
        if _suPerM <= 0 do _suPerM = 1.0
        sqrt(totalUVArea / totalWorldArea) * mapSize * _suPerM
    )
)

global TDT_ScaleUV
fn TDT_ScaleUV objs scaleAmount mapChannel =
(
    if objs.count == 0 do
    ( messageBox "请先选择一个带 UV 的模型。" title:"UV辅助工具"; return false )

    -- 优先：通过 Unwrap UVW 按节点缩放（多模型、不改选择、不关编辑器、实时刷新）
    -- 与「壳对齐」同一套逐节点逻辑；每个模型的 UV 绕自身 UV 中心缩放
    local um = undefined
    local co = undefined
    try( co = modPanel.getCurrentObject() )catch()
    if co != undefined and (classof co == Unwrap_UVW) then um = co
    else
    (
        for o in objs while um == undefined do
            for mi = 1 to o.modifiers.count while um == undefined do
                if (classof o.modifiers[mi]) == Unwrap_UVW do um = o.modifiers[mi]
    )

    if um != undefined then
    (
        local uwi = undefined
        try( uwi = um.unwrap6 )catch()
        if uwi == undefined do
        ( messageBox "当前 Unwrap 修改器不支持多对象接口(unwrap6，需 3ds Max 2008+)。" title:"UV辅助工具"; return false )
        try( uwi.setMapChannel mapChannel )catch()

        local nodes = #()
        try( nodes = refs.dependentNodes um )catch()
        nodes = for n in nodes where (isKindOf n GeometryClass) collect n
        if nodes.count == 0 do
            nodes = for o in objs where ((isKindOf o GeometryClass) and ((findItem o.modifiers um) != 0)) collect o
        if nodes.count == 0 do
        ( messageBox "找不到应用了该 Unwrap 的模型。" title:"UV辅助工具"; return false )

        undo "UV辅助工具 - 缩放UV(多模型)" on
        (
            for nd in nodes do
            (
                local nv = 0
                try( nv = uwi.numberVerticesByNode nd )catch()
                if nv > 0 do
                (
                    local mnx = 1e9; local mny = 1e9; local mxx = -1e9; local mxy = -1e9; local got = false
                    for vi = 1 to nv do
                    (
                        local p = uwi.getVertexPositionByNode currentTime vi nd
                        if p != undefined do ( got = true; if p.x<mnx do mnx=p.x; if p.y<mny do mny=p.y; if p.x>mxx do mxx=p.x; if p.y>mxy do mxy=p.y )
                    )
                    if got do
                    (
                        local cx = (mnx + mxx) * 0.5
                        local cy = (mny + mxy) * 0.5
                        for vi = 1 to nv do
                        (
                            local p = uwi.getVertexPositionByNode currentTime vi nd
                            if p != undefined do
                                uwi.setVertexPositionByNode currentTime vi [cx+(p.x-cx)*scaleAmount, cy+(p.y-cy)*scaleAmount, p.z] nd
                        )
                    )
                )
            )
        )
        -- 仅刷新编辑器，不动选择、不塌陷 → 编辑器保持打开、实时更新
        try( uwi.updateViews() )catch()
        try( uwi.redraw() )catch()
        true
    )
    else
    (
        -- 无 Unwrap 修改器：直接操作底层 UV 通道（不涉及 UV 编辑器，无需改选择）
        undo "UV辅助工具 - 缩放UV(底层)" on
        (
            for obj in objs where isValidNode obj do
            (
                try
                (
                    local _canEdit = (classof obj == Editable_Poly)
                    if not _canEdit do
                    (
                        if obj.modifiers.count > 0 then
                            format "UV辅助工具：跳过 [%]，有修改器堆栈，请先添加 Unwrap UVW 再操作。\n" obj.name
                        else
                        (
                            convertToPoly obj
                            _canEdit = true
                        )
                    )
                    if _canEdit do
                    (
                        if not (polyop.getMapSupport obj mapChannel) do polyop.setMapSupport obj mapChannel true
                        local tvCount = polyop.getNumMapVerts obj mapChannel
                        if tvCount > 0 do
                        (
                            local mn = [1e9, 1e9, 0]
                            local mx = [-1e9, -1e9, 0]
                            for i = 1 to tvCount do
                            (
                                local uv = polyop.getMapVert obj mapChannel i
                                if uv.x < mn.x do mn.x = uv.x
                                if uv.y < mn.y do mn.y = uv.y
                                if uv.x > mx.x do mx.x = uv.x
                                if uv.y > mx.y do mx.y = uv.y
                            )
                            local cx = (mn.x + mx.x) * 0.5
                            local cy = (mn.y + mx.y) * 0.5
                            for i = 1 to tvCount do
                            (
                                local uv = polyop.getMapVert obj mapChannel i
                                polyop.setMapVert obj mapChannel i [cx + (uv.x - cx) * scaleAmount, cy + (uv.y - cy) * scaleAmount, 0]
                            )
                            update obj
                        )
                    )
                )
                catch ( format "UV辅助工具：缩放失败：%\n" obj.name )
            )
        )
        true
    )
)

-- ============================================================
--  RizomUV 桥接
-- ============================================================

global TDT_RB_IniFile
fn TDT_RB_IniFile = ( (getDir #plugcfg) + "\\TDT_RizomBridge.ini" )
global TDT_RB_LoadExe
fn TDT_RB_LoadExe = ( getINISetting (TDT_RB_IniFile()) "RizomUV" "ExePath" )
global TDT_RB_SaveExe
fn TDT_RB_SaveExe p = ( setINISetting (TDT_RB_IniFile()) "RizomUV" "ExePath" p )

global TDT_RB_TempDir
fn TDT_RB_TempDir =
(
    local d = (getDir #temp) + "\\TDT_Rizom\\"
    TDT_MakeDir d
    d
)
global TDT_RB_FbxPath
fn TDT_RB_FbxPath = ( (TDT_RB_TempDir()) + "RizomBridge.fbx" )
global TDT_RB_OutPath
fn TDT_RB_OutPath = ( (TDT_RB_TempDir()) + "RizomBridge_out.fbx" )
global TDT_RB_LuaPath
fn TDT_RB_LuaPath = ( (TDT_RB_TempDir()) + "RizomBridge.lua" )

-- 检查文件是否可读(未被占用)；老版本 Max 无 dotNet 时直接返回 true
global TDT_RB_FileReady
fn TDT_RB_FileReady f =
(
    local ok = true
    try
    (
        local fs = dotNetObject "System.IO.FileStream" f \
            (dotNetClass "System.IO.FileMode").Open \
            (dotNetClass "System.IO.FileAccess").Read \
            (dotNetClass "System.IO.FileShare").None
        fs.Close()
    )
    catch ( ok = false )
    ok
)

global TDT_RB_Launch
fn TDT_RB_Launch exePath luaPath =
(
    try
    (
        local psi = dotNetObject "System.Diagnostics.ProcessStartInfo" exePath
        psi.Arguments = "-cfi \"" + luaPath + "\""
        psi.UseShellExecute = true
        psi.WorkingDirectory = (getFilenamePath exePath)
        (dotNetClass "System.Diagnostics.Process").Start psi
    )
    catch
    (
        -- dotNet 不可用时退回 shellLaunch
        try( shellLaunch exePath ("-cfi \"" + luaPath + "\"") )catch()
    )
)

global TDT_RB_CloseRizom
fn TDT_RB_CloseRizom =
(
    try
    (
        local pname = getFilenameFile (TDT_RB_LoadExe())
        if pname != undefined and pname != "" do
        (
            local procs = (dotNetClass "System.Diagnostics.Process").GetProcessesByName pname
            for p in procs do try( p.Kill() )catch()
        )
    )
    catch ()
)

/*
把 srcNode 的 UV 作为 Unwrap UVW 修改器叠加到 origNode：
  - 删除修改器 → 还原原始 UV
  - 塌陷修改器 → 保留新 UV
原理：临时把新 UV 写入底层 → 加 Unwrap(会读取并存下当前 UV) →
      逐点 setVertexPosition 固化(确保修改器独立存储) → 底层还原原始 UV
*/
global TDT_RB_ApplyUVModifier
fn TDT_RB_ApplyUVModifier origNode srcNode ch =
(
    local ok = false
    try
    (
        convertToPoly srcNode
        convertToPoly origNode

        if not (polyop.getMapSupport srcNode ch) then return false

        local nFaceS = polyop.getNumFaces srcNode
        local nFaceO = polyop.getNumFaces origNode
        if nFaceS != nFaceO then
        (
            format "RizomUV 桥接: 拓扑不一致，跳过 %\n" origNode.name
            return false
        )

        -- 1) 备份原始 UV
        local bkSupport = polyop.getMapSupport origNode ch
        local bkVerts = #()
        local bkFaces = #()
        if bkSupport do
        (
            local bn = polyop.getNumMapVerts origNode ch
            for i = 1 to bn do append bkVerts (polyop.getMapVert origNode ch i)
            for f = 1 to nFaceO do append bkFaces (polyop.getMapFace origNode ch f)
        )

        -- 2) 把新 UV 临时写入原模型底层
        polyop.setMapSupport origNode ch true
        local sn = polyop.getNumMapVerts srcNode ch
        polyop.setNumMapVerts origNode ch sn
        for i = 1 to sn do
            polyop.setMapVert origNode ch i (polyop.getMapVert srcNode ch i)
        for f = 1 to nFaceO do
            polyop.setMapFace origNode ch f (polyop.getMapFace srcNode ch f)
        update origNode

        -- 3) 加 Unwrap UVW 修改器并固化 UV 数据（版本兼容写法）
        local um = Unwrap_UVW name:"RizomUV_UVs"
        addModifier origNode um
        local uwi = TDT_GetUnwrapIF um
        if uwi != undefined do
        (
            try( uwi.setMapChannel ch )catch()
            local nv = 0
            try( nv = uwi.numberVertices() )catch( try( nv = um.numberVertices() )catch() )
            for i = 1 to nv do
            (
                local pos = undefined
                try( pos = uwi.getVertexPosition currentTime i )catch(
                    try( pos = um.getVertexPosition currentTime i )catch() )
                if pos != undefined do
                    try( uwi.setVertexPosition currentTime i pos )catch(
                        try( um.setVertexPosition currentTime i pos )catch() )
            )
        )

        -- 4) 还原底层原始 UV
        if bkSupport then
        (
            polyop.setMapSupport origNode ch true
            polyop.setNumMapVerts origNode ch bkVerts.count
            for i = 1 to bkVerts.count do
                polyop.setMapVert origNode ch i bkVerts[i]
            for f = 1 to nFaceO do
                polyop.setMapFace origNode ch f bkFaces[f]
        )
        else polyop.setMapSupport origNode ch false
        update origNode

        ok = true
    )
    catch ( format "RizomUV 桥接: 应用 UV 修改器失败 %\n" origNode.name )
    ok
)

global TDT_RB_Send
fn TDT_RB_Send keepUV ch =
(
    local exePath = TDT_RB_LoadExe()
    if exePath == undefined or exePath == "" or not (doesFileExist exePath) then
    (
        messageBox "请先点[浏览]指定 rizomuv.exe 的位置。" title:"UV辅助工具"
        return false
    )

    local srcObjs = selection as array
    if srcObjs.count == 0 then
    (
        messageBox "请先选择要发送的模型。" title:"UV辅助工具"
        return false
    )

    TDT_RB_srcObjs = srcObjs

    -- 克隆并统一命名，便于回传精确匹配
    local clones = #()
    maxOps.cloneNodes srcObjs cloneType:#copy newNodes:&clones
    for i = 1 to clones.count do
    (
        local c = clones[i]
        try( convertToPoly c )catch()
        c.name = "RBridge_" + (i as string)
        if not keepUV do
            try( if (polyop.getMapSupport c ch) do polyop.setMapSupport c ch false )catch()
    )

    -- 导出 FBX
    local fbx = TDT_RB_FbxPath()
    try( deleteFile fbx )catch()
    select clones
    try
    (
        FBXExporterSetParam "ResetExport"
        FBXExporterSetParam "SmoothingGroups" true
        FBXExporterSetParam "Triangulate" false
        FBXExporterSetParam "TangentSpaceExport" false
        FBXExporterSetParam "ASCII" false
    )
    catch ()

    local okExp = false
    try( okExp = exportFile fbx #noPrompt selectedOnly:true using:FBXEXP )catch(
        try( okExp = exportFile fbx #noPrompt selectedOnly:true )catch() )
    delete clones
    try( select srcObjs )catch()

    if not okExp then ( messageBox "FBX 导出失败。" title:"UV辅助工具"; return false )

    -- Lua：加载 + 设置保存后缀 _out → Ctrl+S 写回 *_out.fbx
    local fbxFwd = substituteString fbx "\\" "/"
    local loadArgs = if keepUV then "XYZUVW=true, UVWProps=true" else "XYZ=true"
    local lua = "ZomLoad({File={Path=\"" + fbxFwd + "\", ImportGroups=true, " + loadArgs + \
                "}, NormalizeUVW=true})\n" + \
                "ZomSet({Path=\"Prefs.FileSuffix\", Value=\"_out\"})\n"
    local lp = TDT_RB_LuaPath()
    local f = createFile lp
    format "%" lua to:f
    close f

    try( deleteFile (TDT_RB_OutPath()) )catch()
    try
    (
        TDT_RB_baseTime = (dotNetClass "System.DateTime").MinValue
    )
    catch
    (
        TDT_RB_baseTime = 0   -- dotNet 不可用时退回时间戳 0
    )

    TDT_RB_Launch exePath lp
    true
)

global TDT_RB_Receive
fn TDT_RB_Receive ch =
(
    local fbx = TDT_RB_OutPath()
    if not (doesFileExist fbx) then return 0
    if not (TDT_RB_FileReady fbx) then return 0
    if TDT_RB_srcObjs.count == 0 then return 0

    local before = objects as array
    try( FBXImporterSetParam "Mode" #create )catch()
    try( importFile fbx #noPrompt using:FBXIMP )catch(
        try( importFile fbx #noPrompt )catch( return 0 ) )

    local after = objects as array
    local newObjs = for o in after where (findItem before o == 0) collect o

    local applied = 0
    local used = #()
    undo "RizomUV 回传 UV" on
    (
        for i = 1 to TDT_RB_srcObjs.count do
        (
            if isValidNode TDT_RB_srcObjs[i] do
            (
                local nm = "RBridge_" + (i as string)
                local match = undefined
                -- 按名字优先匹配，避免重复占用
                for o in newObjs while match == undefined where \
                    (o.name == nm and (findItem used o == 0)) do match = o
                -- 名字匹配失败时按顺序补齐
                if match == undefined do
                    for o in newObjs while match == undefined where \
                        (findItem used o == 0) do match = o

                if match != undefined do
                (
                    append used match
                    if (TDT_RB_ApplyUVModifier TDT_RB_srcObjs[i] match ch) do applied += 1
                )
            )
        )
    )
    try( delete newObjs )catch()

    -- 回传结束，重新选中发送时的整批模型
    local valids = for o in TDT_RB_srcObjs where (isValidNode o) collect o
    if valids.count > 0 do select valids

    applied
)

-- ============================================================
--  棋盘格预览（非破坏：临时替换材质，可一键还原）
-- ============================================================

global TDT_CK_backup = #()
global TDT_CK_nodes  = #()
global TDT_CK_Dir = (TDT_ScriptDir())

global TDT_CK_FindImage
fn TDT_CK_FindImage mapSize =
(
    local result = undefined
    if TDT_CK_Dir != "" and TDT_CK_Dir != undefined do
    (
        for e in #(".png",".jpg",".jpeg",".tga",".bmp") while result == undefined do
        (
            local p = TDT_CK_Dir + "checker_" + (mapSize as string) + e
            if doesFileExist p do result = p
        )
    )
    result
)

global TDT_CK_BuildMat
fn TDT_CK_BuildMat mapSize ch =
(
    local diff = undefined
    local imgPath = TDT_CK_FindImage mapSize
    if imgPath != undefined then
    (
        diff = Bitmaptexture fileName:imgPath
        diff.coords.mapChannel = ch
    )
    else
    (
        local ck = checker()
        ck.coords.mapChannel = ch
        local tiling = (amax 2.0 (mapSize / 128.0)) / 2.0
        ck.coords.U_Tiling = tiling
        ck.coords.V_Tiling = tiling
        ck.color1 = (color 120 160 90)
        ck.color2 = (color 92 96 165)
        diff = ck
    )
    local m = Standardmaterial name:"TD_Checker"
    m.diffuse = (color 255 255 255)
    m.diffuseMap = diff
    try( m.selfIllumAmount = 100 )catch()
    try( showTextureMap m diff true )catch()
    m
)

global TDT_CK_Clear
fn TDT_CK_Clear =
(
    for i = 1 to TDT_CK_nodes.count do
    (
        local o = TDT_CK_nodes[i]
        if isValidNode o do o.material = TDT_CK_backup[i]
    )
    TDT_CK_nodes  = #()
    TDT_CK_backup = #()
)

global TDT_CK_Apply
fn TDT_CK_Apply objs mapSize ch =
(
    TDT_CK_Clear()
    local mat = TDT_CK_BuildMat mapSize ch
    for o in objs where isValidNode o do
    (
        append TDT_CK_backup o.material
        append TDT_CK_nodes o
        o.material = mat
    )
)

-- ============================================================
--  壳对齐（多个 UV 岛互相对齐，移植自 PolyUnwrapper 的对齐）
-- ============================================================

-- 用 GDI+ 实时绘制对齐按钮的小图标（和设计软件里的对齐图标一样直观）
global TDT_AL_MakeIcon
fn TDT_AL_MakeIcon mode rectClr =
(
    local bmp = undefined
    try
    (
        bmp = dotNetObject "System.Drawing.Bitmap" 20 20
        local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        local bar  = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 236 152 64)
        local rc   = if rectClr != undefined then rectClr else ((dotNetClass "System.Drawing.Color").FromArgb 202 208 216)
        local rect = dotNetObject "System.Drawing.SolidBrush" rc
        case mode of
        (
            #left:    ( g.FillRectangle bar 2 0 2 14;  g.FillRectangle rect 5 1 12 3;  g.FillRectangle rect 5 6 8 3;  g.FillRectangle rect 5 11 11 3 )
            #right:   ( g.FillRectangle bar 16 0 2 14; g.FillRectangle rect 3 1 12 3;  g.FillRectangle rect 7 6 8 3;  g.FillRectangle rect 4 11 11 3 )
            #centerx: ( g.FillRectangle bar 9 0 2 14;  g.FillRectangle rect 4 1 12 3;  g.FillRectangle rect 6 6 8 3;  g.FillRectangle rect 5 11 10 3 )
            #top:     ( g.FillRectangle bar 3 0 14 2;  g.FillRectangle rect 4 2 3 12;  g.FillRectangle rect 9 2 3 8;  g.FillRectangle rect 14 2 3 11 )
            #bottom:  ( g.FillRectangle bar 3 13 14 2; g.FillRectangle rect 4 0 3 12;  g.FillRectangle rect 9 4 3 8;  g.FillRectangle rect 14 1 3 11 )
            #centery: ( g.FillRectangle bar 3 6 14 2;  g.FillRectangle rect 4 1 3 12;  g.FillRectangle rect 9 3 3 8;  g.FillRectangle rect 14 2 3 10 )
            #weld:    ( try(g.SmoothingMode = (dotNetClass "System.Drawing.Drawing2D.SmoothingMode").AntiAlias)catch(); g.FillEllipse rect 2 4 5 5; g.FillEllipse rect 13 4 5 5; g.FillEllipse bar 7 3 7 7 )
            #break:   ( g.FillRectangle rect 2 2 6 10; g.FillRectangle rect 12 2 6 10; g.FillRectangle bar 9 0 2 16 )
            #stitch:  ( g.FillRectangle rect 2 2 6 10; g.FillRectangle rect 12 2 6 10; g.FillRectangle bar 9 1 2 3; g.FillRectangle bar 9 8 2 3 )
        )
        g.Dispose()
    )
    catch ( bmp = undefined )
    bmp
)

-- 把选中的多个 UV 岛(壳)整体平移，按总包围盒对齐——支持多个模型(逐节点)
-- mode: #left #right #centerx #top #bottom #centery
global TDT_AL_AlignShells
fn TDT_AL_AlignShells mode =
(
    -- 取当前 Unwrap UVW 修改器（不改变选择，避免关闭 UV 编辑器）
    local um = undefined
    local co = undefined
    try( co = modPanel.getCurrentObject() )catch()
    if co != undefined and (classof co == Unwrap_UVW) then um = co
    else
    (
        for o in (selection as array) while um == undefined do
            for mi = 1 to o.modifiers.count while um == undefined do
                if (classof o.modifiers[mi]) == Unwrap_UVW do um = o.modifiers[mi]
    )
    if um == undefined do
    ( messageBox "请先进入模型的 Unwrap UVW（UVW 展开）修改器（即打开 UV 编辑器）后再用壳对齐。" title:"UV辅助工具"; return false )

    -- 多对象逐节点接口（unwrap6 / Max 2008+），多个模型共用一个展开也能正确读写
    local uwi = undefined
    try( uwi = um.unwrap6 )catch()
    if uwi == undefined do
    ( messageBox "当前 Unwrap 修改器不支持多对象接口(unwrap6，需 3ds Max 2008+)。" title:"UV辅助工具"; return false )

    -- 该修改器作用的所有模型节点（多对象展开时为多个）
    local nodes = #()
    try( nodes = refs.dependentNodes um )catch()
    nodes = for n in nodes where (isKindOf n GeometryClass) collect n
    if nodes.count == 0 do
        nodes = for o in (selection as array) where ((isKindOf o GeometryClass) and ((findItem o.modifiers um) != 0)) collect o
    if nodes.count == 0 do
    ( messageBox "找不到应用了该 Unwrap 的模型。" title:"UV辅助工具"; return false )

    fn _root parent i = ( while parent[i] != i do ( parent[i] = parent[parent[i]]; i = parent[i] ); i )

    -- 逐节点：建壳(并查集) + 求选中面
    local perNF     = #()
    local perParent = #()
    local perSelF   = #()
    local totalSel  = 0
    for ni = 1 to nodes.count do
    (
        local nd = nodes[ni]
        local nf = 0
        local nv = 0
        try( nf = uwi.numberPolygonsByNode nd )catch()
        try( nv = uwi.numberVerticesByNode nd )catch()
        perNF[ni] = nf
        if nf > 0 and nv > 0 then
        (
            local parent = #()
            parent[nf] = 0
            for i = 1 to nf do parent[i] = i
            local vFace = #()
            vFace[nv] = undefined
            for f = 1 to nf do
            (
                local nc = uwi.numberPointsInFaceByNode f nd
                for c = 1 to nc do
                (
                    local vi = uwi.getVertexIndexFromFaceByNode f c nd
                    if vi > 0 do
                    (
                        local rep = vFace[vi]
                        if rep == undefined then vFace[vi] = f
                        else ( local r1 = _root parent f; local r2 = _root parent rep; if r1 != r2 do parent[r1] = r2 )
                    )
                )
            )
            perParent[ni] = parent

            local selF = undefined
            try( selF = uwi.getSelectedFacesByNode nd )catch()
            if selF == undefined do selF = #{}
            if selF.numberSet == 0 do
            (
                local sv = undefined
                try( sv = uwi.getSelectedVerticesByNode nd )catch()
                if sv != undefined and sv.numberSet != 0 do
                    for f = 1 to nf do
                    (
                        local nc = uwi.numberPointsInFaceByNode f nd
                        local hit = false
                        for c = 1 to nc while not hit do ( local vi = uwi.getVertexIndexFromFaceByNode f c nd; if vi > 0 and sv[vi] do hit = true )
                        if hit do selF[f] = true
                    )
            )
            perSelF[ni] = selF
            totalSel += selF.numberSet
        )
        else ( perParent[ni] = #(); perSelF[ni] = #{} )
    )

    -- 全场都没选 → 直接提示未选中（不再默认对全部岛生效）
    if totalSel == 0 do
    ( messageBox "未选中 UV：请先在 UV 编辑器里选择要对齐的 UV 岛（点 / 边 / 面均可）。" title:"UV辅助工具"; return false )

    -- 收集所有选中岛(跨节点)：island = #(节点序号, 顶点bitarray, 包围盒)
    local islands = #()
    for ni = 1 to nodes.count do
    (
        local nf = perNF[ni]
        if nf > 0 do
        (
            local nd = nodes[ni]
            local parent = perParent[ni]
            local selF = perSelF[ni]
            local isSel = #{}
            for f in selF do isSel[_root parent f] = true
            local rVerts = #()
            local rbb = #()
            for f = 1 to nf do
            (
                local r = _root parent f
                if isSel[r] do
                (
                    if rVerts[r] == undefined do rVerts[r] = #{}
                    local nc = uwi.numberPointsInFaceByNode f nd
                    for c = 1 to nc do
                    (
                        local vi = uwi.getVertexIndexFromFaceByNode f c nd
                        if vi > 0 and (not rVerts[r][vi]) do
                        (
                            rVerts[r][vi] = true
                            local p = uwi.getVertexPositionByNode currentTime vi nd
                            if p != undefined do
                            (
                                local bb = rbb[r]
                                if bb == undefined then rbb[r] = #(p.x,p.y,p.x,p.y)
                                else ( if p.x<bb[1] do bb[1]=p.x; if p.y<bb[2] do bb[2]=p.y; if p.x>bb[3] do bb[3]=p.x; if p.y>bb[4] do bb[4]=p.y )
                            )
                        )
                    )
                )
            )
            for r in isSel where (rbb[r] != undefined) do append islands #(ni, rVerts[r], rbb[r])
        )
    )

    if islands.count == 0 do ( messageBox "没有可对齐的 UV 岛。" title:"UV辅助工具"; return false )
    if islands.count == 1 do
    ( messageBox "只检测到 1 个 UV 岛。\n壳对齐需要至少 2 个岛（可跨多个模型，在 UV 编辑器里多选几个岛再试）。" title:"UV辅助工具"; return false )

    -- 所有选中岛的整体包围盒
    local gb = undefined
    for isl in islands do
    (
        local bb = isl[3]
        if gb == undefined then gb = #(bb[1],bb[2],bb[3],bb[4])
        else ( if bb[1]<gb[1] do gb[1]=bb[1]; if bb[2]<gb[2] do gb[2]=bb[2]; if bb[3]>gb[3] do gb[3]=bb[3]; if bb[4]>gb[4] do gb[4]=bb[4] )
    )
    local gcx = (gb[1]+gb[3])/2.0
    local gcy = (gb[2]+gb[4])/2.0

    undo "UV辅助工具 - 壳对齐(多模型)" on
    (
        for isl in islands do
        (
            local nd = nodes[isl[1]]
            local verts = isl[2]
            local bb = isl[3]
            local dx = 0.0
            local dy = 0.0
            case mode of
            (
                #left:    dx = gb[1] - bb[1]
                #right:   dx = gb[3] - bb[3]
                #centerx: dx = gcx - (bb[1]+bb[3])/2.0
                #top:     dy = gb[4] - bb[4]
                #bottom:  dy = gb[2] - bb[2]
                #centery: dy = gcy - (bb[2]+bb[4])/2.0
            )
            if dx != 0.0 or dy != 0.0 do
                for vi in verts do
                (
                    local p = uwi.getVertexPositionByNode currentTime vi nd
                    if p != undefined do uwi.setVertexPositionByNode currentTime vi [p.x+dx, p.y+dy, p.z] nd
                )
        )
    )
    -- 仅刷新编辑器，不动选择、不塌陷 → 编辑器保持打开、实时更新
    try( uwi.updateViews() )catch()
    try( uwi.redraw() )catch()
    true
)

-- ============================================================
--  焊接相近点（按阈值把相近 UV 点焊到一起，原生焊接=真正合并顶点）
-- ============================================================
global TDT_WeldNear
fn TDT_WeldNear threshold onlyShared =
(
    -- 取当前 Unwrap UVW 修改器（不改变选择）
    local um = undefined
    local co = undefined
    try( co = modPanel.getCurrentObject() )catch()
    if co != undefined and (classof co == Unwrap_UVW) then um = co
    else
    (
        for o in (selection as array) while um == undefined do
            for mi = 1 to o.modifiers.count while um == undefined do
                if (classof o.modifiers[mi]) == Unwrap_UVW do um = o.modifiers[mi]
    )
    if um == undefined do
    ( messageBox "请先进入模型的 Unwrap UVW（UVW 展开）修改器（即打开 UV 编辑器）后再焊接。" title:"UV辅助工具"; return false )

    local ifU  = undefined
    local ifU2 = undefined
    local ifU6 = undefined
    try( ifU  = um.unwrap )catch()
    try( ifU2 = um.unwrap2 )catch()
    try( ifU6 = um.unwrap6 )catch()

    -- 切到点(顶点)子物体模式，确保焊接作用于点
    try( ifU2.setTVSubObjectMode 1 )catch( try( um.setTVSubObjectMode 1 )catch() )

    -- 统计当前选中的 UV 点数（多对象逐节点累加）
    local nSel = 0
    if ifU6 != undefined then
    (
        local nodes = #()
        try( nodes = refs.dependentNodes um )catch()
        nodes = for n in nodes where (isKindOf n GeometryClass) collect n
        for nd in nodes do
        ( local sv = undefined; try( sv = ifU6.getSelectedVerticesByNode nd )catch(); if sv != undefined do nSel += sv.numberSet )
    )
    else ( try( nSel = (um.getSelectedVertices()).numberSet )catch() )

    if nSel == 0 do
    ( messageBox "请先在 UV 编辑器的【点模式】下选择要焊接的点。\n（要焊接整张 UV：先在编辑器里按 Ctrl+A 全选点，再点焊接）" title:"UV辅助工具"; return false )

    -- 设阈值 + 焊接模式（勾选=只焊 UV 缝/同一网格顶点；取消=焊任意相近点）
    try( ifU.setWeldThreshold threshold )catch( try( um.setWeldThreshold threshold )catch() )
    try( um.weldOnlyShared = onlyShared )catch()

    -- 原生焊接：按阈值把选中的相近点合并（原生自动处理多对象、可 Ctrl+Z 撤销）
    try( ifU.weldSelected() )catch( try( um.weldSelected() )catch() )

    -- 刷新编辑器（保持打开、实时）
    try( ifU6.updateViews() )catch( try( um.updateViews() )catch() )
    try( ifU6.redraw() )catch( try( um.redraw() )catch() )
    true
)

-- ============================================================
--  断开 / 缝合 UV（用原生 break / stitch，但封装得更稳、支持多模型、不关编辑器）
-- ============================================================

-- 取当前/选中物体上的 Unwrap UVW 修改器
global TDT_GetUVMod
fn TDT_GetUVMod =
(
    local um = undefined
    local co = undefined
    try( co = modPanel.getCurrentObject() )catch()
    if co != undefined and (classof co == Unwrap_UVW) then um = co
    else
    (
        for o in (selection as array) while um == undefined do
            for mi = 1 to o.modifiers.count while um == undefined do
                if (classof o.modifiers[mi]) == Unwrap_UVW do um = o.modifiers[mi]
    )
    um
)

-- 断开：把选中的 UV 子物体(点/边/面)拆开（原生 breakSelected）
global TDT_BreakUV
fn TDT_BreakUV =
(
    local um = TDT_GetUVMod()
    if um == undefined do
    ( messageBox "请先进入模型的 Unwrap UVW（UVW 展开）修改器（即打开 UV 编辑器）后再断开。" title:"UV辅助工具"; return false )
    local ifU  = undefined
    local ifU6 = undefined
    try( ifU  = um.unwrap )catch()
    try( ifU6 = um.unwrap6 )catch()
    try( ifU.breakSelected() )catch( try( um.breakSelected() )catch() )
    try( ifU6.updateViews() )catch( try( um.updateViews() )catch() )
    try( ifU6.redraw() )catch( try( um.redraw() )catch() )
    true
)

-- 缝合：把选中边/点对应、属于同一网格顶点的 UV 点拉到一起并焊上（原生 stitchVerts）
global TDT_StitchUV
fn TDT_StitchUV =
(
    local um = TDT_GetUVMod()
    if um == undefined do
    ( messageBox "请先进入模型的 Unwrap UVW（UVW 展开）修改器（即打开 UV 编辑器）后再缝合。" title:"UV辅助工具"; return false )
    local ifU2 = undefined
    local ifU6 = undefined
    try( ifU2 = um.unwrap2 )catch()
    try( ifU6 = um.unwrap6 )catch()
    -- align=true 先对齐簇再缝合（更容易缝上），bias=0.0
    try( ifU2.stitchVerts true 0.0 )catch(
        try( um.stitchVerts true 0.0 )catch(
            try( ifU2.stitchVertsNoParams() )catch(
                try( um.stitchVertsNoParams() )catch() ) ) )
    try( ifU6.updateViews() )catch( try( um.updateViews() )catch() )
    try( ifU6.redraw() )catch( try( um.redraw() )catch() )
    true
)

-- ============================================================
--  界面
-- ============================================================

rollout TDT_MainTool "UV辅助工具" width:360 height:568
(
    -- ===== UV精度调整 =====
    -- 布局节奏：hdr(22) → 4 → FrameP(32):[btnChecker(24)] → 4 → FrameC(32) → 4 → FrameA(62) → 4 → FrameB(32) → 6
    groupBox grpDensity "" pos:[10,6] width:340 height:204
    dotNetControl hdrDensity "System.Windows.Forms.Label" pos:[12,8] width:336 height:22

    -- 棋盘格预览（全宽，排在最上面）
    dotNetControl btnChecker "System.Windows.Forms.Button" pos:[20,38] width:320 height:24

    -- Frame P: 棋盘格预览  y:34~66
    dotNetControl fpT "System.Windows.Forms.Panel" pos:[16,34]  width:328 height:1
    dotNetControl fpB "System.Windows.Forms.Panel" pos:[16,66]  width:328 height:1
    dotNetControl fpL "System.Windows.Forms.Panel" pos:[16,34]  width:1   height:32
    dotNetControl fpR "System.Windows.Forms.Panel" pos:[343,34] width:1   height:32

    -- Frame C: 贴图尺寸 + UV通道  y:70~102
    dotNetControl fcT "System.Windows.Forms.Panel" pos:[16,70]  width:328 height:1
    dotNetControl fcB "System.Windows.Forms.Panel" pos:[16,102] width:328 height:1
    dotNetControl fcL "System.Windows.Forms.Panel" pos:[16,70]  width:1   height:32
    dotNetControl fcR "System.Windows.Forms.Panel" pos:[343,70] width:1   height:32
    label        lblMap     "贴图尺寸" pos:[20,78]  width:50  height:20
    dropdownlist ddlMap     "" pos:[74,76] width:118 \
                 items:#("256 x 256","512 x 512","1024 x 1024","2048 x 2048","4096 x 4096","8192 x 8192") selection:3
    label        lblChannel "UV 通道"  pos:[200,78] width:54  height:20
    spinner      spnChannel "" pos:[258,76] width:82 height:24 range:[1,99,1] type:#integer \
                 tooltip:"贴图精度与 RizomUV 桥接共用的 UV 通道，默认 1"

    -- Frame A: 目标精度 + Get/Set  y:106~168
    dotNetControl faT "System.Windows.Forms.Panel" pos:[16,106] width:328 height:1
    dotNetControl faB "System.Windows.Forms.Panel" pos:[16,168] width:328 height:1
    dotNetControl faL "System.Windows.Forms.Panel" pos:[16,106] width:1   height:62
    dotNetControl faR "System.Windows.Forms.Panel" pos:[343,106] width:1  height:62
    label    lblDensity "目标精度 px/m" pos:[24,114]  width:128 height:20
    spinner  spnDensity "" pos:[156,112] width:182 height:24 range:[0,999999,3291] type:#float scale:1 \
             tooltip:"目标贴图精度，单位：像素/米"
    dotNetControl btnGet "System.Windows.Forms.Button" pos:[20,142]  width:157 height:24
    dotNetControl btnSet "System.Windows.Forms.Button" pos:[183,142] width:157 height:24

    -- Frame B: UV缩放倍数 + 开始缩放UV  y:172~204
    dotNetControl fbT "System.Windows.Forms.Panel" pos:[16,172] width:328 height:1
    dotNetControl fbB "System.Windows.Forms.Panel" pos:[16,204] width:328 height:1
    dotNetControl fbL "System.Windows.Forms.Panel" pos:[16,172] width:1   height:32
    dotNetControl fbR "System.Windows.Forms.Panel" pos:[343,172] width:1  height:32
    label    lblScaleVal "UV缩放倍数" pos:[20,180]  width:88 height:20
    spinner  spnScale    "" pos:[112,178] width:58 height:24 range:[0.001,1000,1.0] type:#float scale:0.1 \
             tooltip:"UV 缩放倍数，以 UV 中心为轴、U/V 同时缩放"
    dotNetControl btnScale "System.Windows.Forms.Button" pos:[176,176] width:164 height:24

    -- ===== RizomUV 桥接（放在最下面）=====
    groupBox grpRizom "" pos:[10,412] width:340 height:148
    dotNetControl hdrRizom "System.Windows.Forms.Label" pos:[12,414] width:336 height:22
    -- Frame D: 选择版本 + 路径
    dotNetControl fdT "System.Windows.Forms.Panel" pos:[16,438] width:328 height:1
    dotNetControl fdB "System.Windows.Forms.Panel" pos:[16,498] width:328 height:1
    dotNetControl fdL "System.Windows.Forms.Panel" pos:[16,438] width:1   height:60
    dotNetControl fdR "System.Windows.Forms.Panel" pos:[343,438] width:1  height:60
    dotNetControl btnBrowse "System.Windows.Forms.Button" pos:[20,442] width:320 height:24
    edittext txtExe "" pos:[20,470] width:320 height:24 readOnly:true \
             tooltip:"rizomuv.exe 的完整路径"
    -- Frame E: 发送按钮组
    dotNetControl feT "System.Windows.Forms.Panel" pos:[16,502] width:328 height:1
    dotNetControl feB "System.Windows.Forms.Panel" pos:[16,534] width:328 height:1
    dotNetControl feL "System.Windows.Forms.Panel" pos:[16,502] width:1   height:32
    dotNetControl feR "System.Windows.Forms.Panel" pos:[343,502] width:1  height:32
    dotNetControl btnSendKeep  "System.Windows.Forms.Button" pos:[20,506]  width:157 height:24
    dotNetControl btnSendReset "System.Windows.Forms.Button" pos:[183,506] width:157 height:24
    label    lblStatus "就绪。" pos:[20,538] width:316 height:18

    -- ===== UV 编辑：对齐 / 焊接 / 断开缝合（合并为一个模块，内部分 3 个子框）=====
    groupBox grpEdit "" pos:[10,214] width:340 height:192
    dotNetControl hdrEdit "System.Windows.Forms.Label" pos:[12,216] width:336 height:22

    -- 子框1：壳对齐 6 向（y:242~310）
    dotNetControl gaT "System.Windows.Forms.Panel" pos:[16,242]  width:328 height:1
    dotNetControl gaB "System.Windows.Forms.Panel" pos:[16,310]  width:328 height:1
    dotNetControl gaL "System.Windows.Forms.Panel" pos:[16,242]  width:1   height:68
    dotNetControl gaR "System.Windows.Forms.Panel" pos:[343,242] width:1   height:68
    dotNetControl btnAlignL  "System.Windows.Forms.Button" pos:[22,248]  width:100 height:26
    dotNetControl btnAlignCX "System.Windows.Forms.Button" pos:[131,248] width:100 height:26
    dotNetControl btnAlignR  "System.Windows.Forms.Button" pos:[240,248] width:100 height:26
    dotNetControl btnAlignT  "System.Windows.Forms.Button" pos:[22,278]  width:100 height:26
    dotNetControl btnAlignCY "System.Windows.Forms.Button" pos:[131,278] width:100 height:26
    dotNetControl btnAlignB  "System.Windows.Forms.Button" pos:[240,278] width:100 height:26

    -- 子框2：焊接相近点（阈值 + 按钮，y:316~354）
    dotNetControl gwT "System.Windows.Forms.Panel" pos:[16,316]  width:328 height:1
    dotNetControl gwB "System.Windows.Forms.Panel" pos:[16,354]  width:328 height:1
    dotNetControl gwL "System.Windows.Forms.Panel" pos:[16,316]  width:1   height:38
    dotNetControl gwR "System.Windows.Forms.Panel" pos:[343,316] width:1   height:38
    label    lblWeldT "阈值" pos:[22,332] width:34 height:18
    spinner  spnWeld  "" pos:[58,330] width:66 height:18 range:[0.0001,1.0,0.01] type:#float scale:0.001 \
             tooltip:"两点距离小于该值才会被焊接(UV单位，0~1空间)；默认 0.01"
    dotNetControl btnWeld "System.Windows.Forms.Button" pos:[134,324] width:206 height:24

    -- 子框3：断开 / 缝合（y:360~400）
    dotNetControl gsT "System.Windows.Forms.Panel" pos:[16,360]  width:328 height:1
    dotNetControl gsB "System.Windows.Forms.Panel" pos:[16,400]  width:328 height:1
    dotNetControl gsL "System.Windows.Forms.Panel" pos:[16,360]  width:1   height:40
    dotNetControl gsR "System.Windows.Forms.Panel" pos:[343,360] width:1   height:40
    dotNetControl btnBreak  "System.Windows.Forms.Button" pos:[22,366]  width:150 height:26
    dotNetControl btnStitch "System.Windows.Forms.Button" pos:[190,366] width:150 height:26

    timer tmrWatch interval:1000 active:false

    -- ── 折叠状态 ──────────────────────────────────────────────────
    local secHdr       = #()
    local secGrp       = #()
    local secBody      = #()
    local secTitle     = #("UV精度调整", "UV 编辑 · 对齐 / 焊接 / 断开缝合", "RizomUV 桥接")
    local secHeight    = #(204, 192, 148)
    local secCollapsed = #(false, false, false)
    local origHdrY     = #()
    local origGrpY     = #()
    local origBodyY    = #()

    fn _cY c     = ( local r = undefined ; try ( r = c.pos.y ) catch () ; if r == undefined do try ( r = c.Top ) catch () ; if r == undefined do r = 0 ; r )
    fn _cMoveY c yy = ( local ok = false ; try ( c.pos = [c.pos.x, yy] ; ok = true ) catch () ; if not ok do try ( c.Top = yy ) catch () )
    fn _cVis c v = ( try ( c.visible = v ) catch () )

    fn TDT_relayout =
    (
        if secHdr.count != 3 or origHdrY.count != 3 do return false
        local y = origGrpY[1]
        for s = 1 to 3 do
        (
            local grp   = secGrp[s]
            local hdr   = secHdr[s]
            local shift = y - origGrpY[s]
            try ( grp.pos = [grp.pos.x, y] ) catch ()
            _cMoveY hdr (origHdrY[s] + shift)
            try ( hdr.text = (if secCollapsed[s] then "▶  " else "▼  ") + secTitle[s] ) catch ()
            if secCollapsed[s] then
            (
                try ( grp.height = 26 ) catch ()
                for c in secBody[s] do ( _cVis c false ; _cMoveY c 3000 )
                y += 26
            )
            else
            (
                try ( grp.height = secHeight[s] ) catch ()
                local oy = origBodyY[s]
                for i = 1 to secBody[s].count do
                (
                    _cMoveY secBody[s][i] (oy[i] + shift)
                    _cVis   secBody[s][i] true
                )
                y += secHeight[s]
            )
            if s < 3 do y += 4
        )
        for h in secHdr do try ( h.BringToFront() ) catch ()
        try ( TDT_MainTool.height = y + 8 ) catch ()
        true
    )

    fn TDT_toggle idx =
    (
        secCollapsed[idx] = not secCollapsed[idx]
        TDT_relayout()
        local _f = TDT_RB_IniFile()
        try ( local cs = "" ; for i = 1 to 3 do cs += (if secCollapsed[i] then "1" else "0") ; setINISetting _f "CollapseState" "sections" cs ) catch ()
    )

    on TDT_MainTool open do
    (
        local p = TDT_RB_LoadExe()
        if p != undefined and p != "" do txtExe.text = p

        local flatF   = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
        local cBtn    = (dotNetClass "System.Drawing.Color").FromArgb 0 0 0
        local cBtnTxt = (dotNetClass "System.Drawing.Color").FromArgb 202 208 216
        local cBorder = (dotNetClass "System.Drawing.Color").FromArgb 90 90 90
        local cHover  = (dotNetClass "System.Drawing.Color").FromArgb 88 88 88
        local cDown   = (dotNetClass "System.Drawing.Color").FromArgb 122 122 122
        local fntUI   = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 9

        fn _sb b txt flatF cBtn cBtnTxt cBorder cHover cDown fntUI =
        (
            try
            (
                b.text = txt
                b.flatStyle = flatF
                b.useVisualStyleBackColor = false
                b.backColor = cBtn
                b.foreColor = cBtnTxt
                b.font      = fntUI
                b.flatAppearance.borderSize  = 1
                b.flatAppearance.borderColor = cBorder
                b.flatAppearance.MouseOverBackColor = cHover
                b.flatAppearance.MouseDownBackColor = cDown
            )
            catch ()
        )

        local fntHdr   = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 11 ((dotNetClass "System.Drawing.FontStyle").Bold)
        local midAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        local clrWhite = (dotNetClass "System.Drawing.Color").White

        fn _mkClr r g b = ((dotNetClass "System.Drawing.Color").FromArgb r g b)

        fn _sh h txt col clrWhite fntHdr midAlign =
        (
            try
            (
                h.text      = txt
                h.backColor = col
                h.foreColor = clrWhite
                h.font      = fntHdr
                h.textAlign = midAlign
            )
            catch ()
        )

        _sh hdrDensity "UV精度调整"          (_mkClr 80 132 151)  clrWhite fntHdr midAlign
        _sh hdrRizom   "RizomUV 桥接"      (_mkClr 138 108 168) clrWhite fntHdr midAlign

        _sb btnGet       "获取平均精度"            flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnSet       "应用到目标"             flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnChecker   "棋盘格预览（关）"         flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnScale     "开始缩放UV"              flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnBrowse    "选择桥接所需的 Rizom UV 版本"                flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnSendKeep  "发送 · 保留当前 UV"     flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnSendReset "发送 · 重置 UV 重展开"  flatF cBtn cBtnTxt cBorder cHover cDown fntUI

        global TDT_ToolTip = dotNetObject "System.Windows.Forms.ToolTip"
        try ( TDT_ToolTip.InitialDelay = 400   ) catch()
        try ( TDT_ToolTip.AutoPopDelay = 14000 ) catch()
        try ( TDT_ToolTip.ReshowDelay  = 200   ) catch()

        try ( TDT_ToolTip.SetToolTip btnChecker \
            "【棋盘格预览】\n" + \
            "临时给选中模型贴上棋盘格，直观检查 UV 精度与拉伸情况：\n" + \
            "  正方格 → UV 无拉伸；  长方格 → 存在拉伸需修正；\n" + \
            "  格子越密 → 贴图密度越高（贴图看起来越小）。\n" + \
            "不破坏原材质，关闭后自动还原；切换贴图尺寸或 UV 通道时实时更新。\n" + \
            "用法：选模型 → 点击开启 → 再点一次关闭。" ) catch()

        try ( TDT_ToolTip.SetToolTip btnGet \
            "【获取选中模型的平均 UV 精度】\n" + \
            "读取选中模型的贴图密度（像素/米 px/m），结果填入「目标精度」框。\n" + \
            "选中单个模型 → 直接读取该模型的精度；\n" + \
            "选中多个模型 → 取所有模型精度的平均值填入（供统一调整参考）。\n" + \
            "常见参考值：512 px/m 低精度 / 1024 px/m 标准 / 2048 px/m 高精度。" ) catch()

        try ( TDT_ToolTip.SetToolTip btnSet \
            "【应用目标精度到选中模型】\n" + \
            "自动缩放选中模型的 UV，使其贴图密度达到「目标精度」的设定值。\n" + \
            "支持多选，每个模型以自身当前密度为基准独立计算缩放比例。\n" + \
            "用法：点「获取」读出当前密度 → 修改「目标精度」框 → 点此应用。" ) catch()

        try ( TDT_ToolTip.SetToolTip btnScale \
            "【缩放 UV】\n" + \
            "按「UV缩放倍数」等比缩放所有选中模型的 UV。\n" + \
            "  倍数 > 1 → UV 放大（贴图在模型上显示变小）\n" + \
            "  倍数 < 1 → UV 缩小（贴图在模型上显示变大）\n" + \
            "每个模型以自身 UV 包围盒中心为轴，U/V 同时缩放，支持多选批量处理。\n" + \
            "有 Unwrap 修改器时：通过修改器接口缩放，UV 编辑器实时刷新结果；\n" + \
            "  若操作后 UV 编辑器关闭，属正常现象，重新打开即可，UV 数据不受影响。\n" + \
            "无 Unwrap 修改器时：直接修改底层 UV 通道。" ) catch()

        try ( TDT_ToolTip.SetToolTip btnBrowse \
            "【指定 RizomUV 程序路径】\n" + \
            "设置 rizomuv.exe 的安装位置，是使用全部桥接功能的前提。\n" + \
            "路径一次设置后自动保存，之后打开工具无需重复操作。\n" + \
            "用法：点击 → 在对话框中选中 rizomuv.exe。\n" + \
            "      默认安装目录通常为：C:\\Program Files\\Rizom Lab\\RizomUV ...\\。" ) catch()

        try ( TDT_ToolTip.SetToolTip btnSendKeep \
            "【发送到 RizomUV · 保留现有 UV】\n" + \
            "带现有 UV 将选中模型发到 RizomUV，适合对已有展开进行微调或优化。\n" + \
            "用法：选模型 → 点击 → 在 RizomUV 中操作完成后按 Ctrl+S 保存，\n" + \
            "      Max 自动接收并给每个模型加 RizomUV_UVs 修改器。\n" + \
            "  · 删除该修改器 → 还原到发送前的原始 UV\n" + \
            "  · 塌陷该修改器 → 永久应用新 UV，可继续编辑" ) catch()

        try ( TDT_ToolTip.SetToolTip btnSendReset \
            "【发送到 RizomUV · 重置重新展开】\n" + \
            "清空现有 UV 后将选中模型发到 RizomUV，适合从零开始做全新展开。\n" + \
            "用法：选模型 → 点击 → 在 RizomUV 中展开完成后按 Ctrl+S 保存，\n" + \
            "      Max 自动接收并给每个模型加 RizomUV_UVs 修改器。\n" + \
            "  · 删除该修改器 → 还原到展开前的原始 UV\n" + \
            "  · 塌陷该修改器 → 永久应用新 UV，可继续编辑" ) catch()
        local cPanel = (dotNetClass "System.Drawing.Color").FromArgb 210 210 210
        for p in #(fpT,fpB,fpL,fpR, faT,faB,faL,faR, fbT,fbB,fbL,fbR, fcT,fcB,fcL,fcR, fdT,fdB,fdL,fdR, feT,feB,feL,feR, \
                   gaT,gaB,gaL,gaR, gwT,gwB,gwL,gwR, gsT,gsB,gsL,gsR) do
            try ( p.backColor = cPanel ) catch()

        -- UV 编辑模块 统一标题
        _sh hdrEdit "UV 编辑 · 对齐 / 焊接 / 断开缝合" (_mkClr 110 120 145) clrWhite fntHdr midAlign
        -- 壳对齐 图标按钮
        local _alignDefs = #( \
            #(btnAlignL,  "左对齐",   #left), \
            #(btnAlignCX, "水平居中", #centerx), \
            #(btnAlignR,  "右对齐",   #right), \
            #(btnAlignT,  "顶对齐",   #top), \
            #(btnAlignCY, "垂直居中", #centery), \
            #(btnAlignB,  "底对齐",   #bottom) )
        local _imgL = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
        local _midC = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        local _tir  = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageBeforeText
        for d in _alignDefs do
        (
            _sb d[1] d[2] flatF cBtn cBtnTxt cBorder cHover cDown fntUI
            try
            (
                local ic = TDT_AL_MakeIcon d[3] cBtnTxt
                if ic != undefined do
                (
                    d[1].Image = ic
                    d[1].ImageAlign = _imgL
                    d[1].TextAlign  = _imgL
                    d[1].TextImageRelation = _tir
                )
            ) catch ()
        )
        try ( TDT_ToolTip.SetToolTip btnAlignL  "把所有选中的 UV 岛的【左边】对齐到最左那个岛的左边" ) catch()
        try ( TDT_ToolTip.SetToolTip btnAlignCX "把所有选中的 UV 岛在【水平方向(X)】居中对齐" ) catch()
        try ( TDT_ToolTip.SetToolTip btnAlignR  "把所有选中的 UV 岛的【右边】对齐到最右那个岛的右边" ) catch()
        try ( TDT_ToolTip.SetToolTip btnAlignT  "把所有选中的 UV 岛的【上边】对齐到最上那个岛的上边" ) catch()
        try ( TDT_ToolTip.SetToolTip btnAlignCY "把所有选中的 UV 岛在【垂直方向(Y)】居中对齐" ) catch()
        try ( TDT_ToolTip.SetToolTip btnAlignB  "把所有选中的 UV 岛的【下边】对齐到最下那个岛的下边" ) catch()

        -- 焊接按钮(带焊接图标)
        _sb btnWeld "焊接相近点" flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        try
        (
            local icw = TDT_AL_MakeIcon #weld cBtnTxt
            if icw != undefined do
            (
                btnWeld.Image = icw
                btnWeld.ImageAlign = _imgL
                btnWeld.TextAlign  = _imgL
                btnWeld.TextImageRelation = _tir
            )
        ) catch ()
        try ( TDT_ToolTip.SetToolTip btnWeld \
            "【焊接相近点】\n在点模式下选中要处理的 UV 点(整张UV可先按 Ctrl+A 全选)，\n按左侧『阈值』把相距小于阈值的点焊接合并(默认 0.01)。\n支持多个模型；不会关闭 UV 编辑器。" ) catch()

        -- 断开 / 缝合 按钮(带图标)
        _sb btnBreak  "断开UV" flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        _sb btnStitch "缝合UV" flatF cBtn cBtnTxt cBorder cHover cDown fntUI
        try ( local icb = TDT_AL_MakeIcon #break cBtnTxt;  if icb != undefined do ( btnBreak.Image  = icb; btnBreak.ImageAlign  = _imgL; btnBreak.TextAlign  = _imgL; btnBreak.TextImageRelation  = _tir ) ) catch ()
        try ( local ics = TDT_AL_MakeIcon #stitch cBtnTxt; if ics != undefined do ( btnStitch.Image = ics; btnStitch.ImageAlign = _imgL; btnStitch.TextAlign = _imgL; btnStitch.TextImageRelation = _tir ) ) catch ()
        try ( TDT_ToolTip.SetToolTip btnBreak \
            "【断开UV】比 Max 自带更稳的断开：\n  · 点模式选点 → 把点拆开\n  · 边模式选边 → 沿边切开成缝\n  · 面模式选面 → 拆成独立 UV 块\n支持多个模型；不会关闭 UV 编辑器。" ) catch()
        try ( TDT_ToolTip.SetToolTip btnStitch \
            "【缝合UV】比 Max 自带更稳的缝合：\n把选中边/点对应、属于同一网格顶点的 UV 点拉到一起并焊上，\n将断开的 UV 块沿缝重新缝合(自动对齐簇，更容易缝上)。\n用法：边模式下选中要缝合的边再点此。\n支持多个模型；不会关闭 UV 编辑器。" ) catch()

        -- 图标按钮内容左对齐：L = (按钮宽 - 图标20 - 间距4 - 文字宽) / 2 使左右留白相等
        try
        (
            local _tmpBmp = dotNetObject "System.Drawing.Bitmap" 1 1
            local _gM = (dotNetClass "System.Drawing.Graphics").FromImage _tmpBmp
            fn _setIcoLP btn gM =
            (
                try
                (
                    local tw = (gM.MeasureString btn.Text btn.Font).Width
                    local lp = ((btn.Width - (20 + 4 + tw)) / 2) as integer
                    if lp > 0 do btn.Padding = dotNetObject "System.Windows.Forms.Padding" lp 0 0 0
                ) catch ()
            )
            for d in _alignDefs do _setIcoLP d[1] _gM
            _setIcoLP btnWeld   _gM
            _setIcoLP btnBreak  _gM
            _setIcoLP btnStitch _gM
            try ( _gM.Dispose() ) catch ()
            try ( _tmpBmp.Dispose() ) catch ()
        ) catch ()

        -- ── 折叠模块初始化 ────────────────────────────────────────
        secHdr = #(hdrDensity, hdrEdit, hdrRizom)
        secGrp = #(grpDensity, grpEdit, grpRizom)
        secBody = #(
            #(btnChecker,
              fpT,fpB,fpL,fpR, fcT,fcB,fcL,fcR,
              lblMap,ddlMap,lblChannel,spnChannel,
              faT,faB,faL,faR, lblDensity,spnDensity,btnGet,btnSet,
              fbT,fbB,fbL,fbR, lblScaleVal,spnScale,btnScale),
            #(gaT,gaB,gaL,gaR,
              btnAlignL,btnAlignCX,btnAlignR,btnAlignT,btnAlignCY,btnAlignB,
              gwT,gwB,gwL,gwR, lblWeldT,spnWeld,btnWeld,
              gsT,gsB,gsL,gsR, btnBreak,btnStitch),
            #(fdT,fdB,fdL,fdR, btnBrowse,txtExe,
              feT,feB,feL,feR, btnSendKeep,btnSendReset,lblStatus)
        )
        try ( origHdrY  = for h in secHdr collect (_cY h) ) catch ()
        try ( origGrpY  = for g in secGrp collect (_cY g) ) catch ()
        try ( origBodyY = for bd in secBody collect (for c in bd collect (_cY c)) ) catch ()
        try ( local hcur = (dotNetClass "System.Windows.Forms.Cursors").Hand ; for h in secHdr do try ( h.Cursor = hcur ) catch () ) catch ()
        -- 读取上次保存的折叠状态
        try
        (
            local _f = TDT_RB_IniFile()
            local cs = getINISetting _f "CollapseState" "sections"
            if cs != undefined and cs.count >= 3 do
                for i = 1 to 3 do secCollapsed[i] = ((substring cs i 1) == "1")
        ) catch ()
        TDT_relayout()
    )

    on TDT_MainTool close do
    (
        TDT_CK_Clear()
        local _f = TDT_RB_IniFile()
        try ( local cs = "" ; for i = 1 to 3 do cs += (if secCollapsed[i] then "1" else "0") ; setINISetting _f "CollapseState" "sections" cs ) catch ()
    )

    -- ----- 折叠标题 -----
    on hdrDensity mouseDown s a do TDT_toggle 1
    on hdrEdit    mouseDown s a do TDT_toggle 2
    on hdrRizom   mouseDown s a do TDT_toggle 3

    -- ----- 棋盘格 -----
    on btnChecker click do
    (
        if btnChecker.text == "棋盘格预览（关）" then
        (
            local objs = selection as array
            if objs.count == 0 then
                messageBox "请先选择模型，再开启棋盘格预览。" title:"UV辅助工具"
            else
            (
                TDT_CK_Apply objs (TDT_GetMapSize ddlMap.selection) spnChannel.value
                btnChecker.text = "棋盘格预览（开）"
                try ( btnChecker.backColor = (dotNetClass "System.Drawing.Color").FromArgb 50 50 50 ) catch()
            )
        )
        else
        (
            TDT_CK_Clear()
            btnChecker.text = "棋盘格预览（关）"
            try ( btnChecker.backColor = (dotNetClass "System.Drawing.Color").FromArgb 0 0 0 ) catch()
        )
    )

    on ddlMap selected i do
    (
        if btnChecker.text == "棋盘格预览（开）" do
        (
            local objs = for o in TDT_CK_nodes where (isValidNode o) collect o
            if objs.count > 0 do
                TDT_CK_Apply objs (TDT_GetMapSize ddlMap.selection) spnChannel.value
        )
    )

    on spnChannel changed val do
    (
        if btnChecker.text == "棋盘格预览（开）" do
        (
            local objs = for o in TDT_CK_nodes where (isValidNode o) collect o
            if objs.count > 0 do
                TDT_CK_Apply objs (TDT_GetMapSize ddlMap.selection) spnChannel.value
        )
    )

    -- ----- 贴图密度 -----
    on btnGet click do
    (
        local td = TDT_CalcTexelDensity selection (TDT_GetMapSize ddlMap.selection) spnChannel.value
        if td > 0 then
        (
            spnDensity.value = td
            format "贴图密度：% 像素/米\n" td
        )
        else messageBox "无法计算贴图密度。\n请确认：\n1. 已选择模型\n2. 模型带有 UV\n3. 使用了正确的 UV 通道" title:"UV辅助工具"
    )

    on btnSet click do
    (
        local mapSize   = TDT_GetMapSize ddlMap.selection
        local currentTD = TDT_CalcTexelDensity selection mapSize spnChannel.value
        if currentTD <= 0 then
            messageBox "无法计算当前贴图密度，无法应用。" title:"UV辅助工具"
        else
        (
            local targetTD = spnDensity.value
            if targetTD <= 0 then
                messageBox "目标贴图密度必须大于 0。" title:"UV辅助工具"
            else
            (
                local factor = targetTD / currentTD
                TDT_ScaleUV (selection as array) factor spnChannel.value
                format "应用贴图密度：当前 %，目标 %，缩放系数 %\n" currentTD targetTD factor
            )
        )
    )

    -- ----- UV 缩放 -----
    on btnScale click do
        TDT_ScaleUV (selection as array) spnScale.value spnChannel.value

    -- ----- 壳对齐 -----
    on btnAlignL  click do TDT_AL_AlignShells #left
    on btnAlignCX click do TDT_AL_AlignShells #centerx
    on btnAlignR  click do TDT_AL_AlignShells #right
    on btnAlignT  click do TDT_AL_AlignShells #top
    on btnAlignCY click do TDT_AL_AlignShells #centery
    on btnAlignB  click do TDT_AL_AlignShells #bottom

    -- ----- 焊接 / 断开 / 缝合 -----
    on btnWeld   click do TDT_WeldNear spnWeld.value false
    on btnBreak  click do TDT_BreakUV()
    on btnStitch click do TDT_StitchUV()

    -- ----- RizomUV 桥接 -----
    on btnBrowse click do
    (
        local p = getOpenFileName caption:"选择 rizomuv.exe" \
                      types:"RizomUV(*.exe)|*.exe|所有文件(*.*)|*.*|"
        if p != undefined and p != "" do
        (
            TDT_RB_SaveExe p
            txtExe.text = p
            lblStatus.text = "已设置 RizomUV 路径。"
        )
    )

    on btnSendKeep click do
    (
        if (TDT_RB_Send true spnChannel.value) do
        (
            tmrWatch.active = true
            lblStatus.text = "已发送(保留UV)。在 RizomUV 按 Ctrl+S 即自动回传。"
        )
    )

    on btnSendReset click do
    (
        if (TDT_RB_Send false spnChannel.value) do
        (
            tmrWatch.active = true
            lblStatus.text = "已发送(重置UV)。展开后按 Ctrl+S 即自动回传。"
        )
    )

    on tmrWatch tick do
    (
        if TDT_RB_baseTime != undefined do
        (
            local fbx = TDT_RB_OutPath()
            if doesFileExist fbx do
            (
                local changed = false
                try
                (
                    local cur = (dotNetClass "System.IO.File").GetLastWriteTime fbx
                    changed = ((dotNetClass "System.DateTime").Compare cur TDT_RB_baseTime) > 0
                )
                catch
                (
                    -- dotNet 不可用时用文件大小变化粗略判断
                    changed = (getFileSize fbx) > 0
                )

                if changed do
                (
                    if TDT_RB_FileReady fbx do
                    (
                        local n = TDT_RB_Receive spnChannel.value
                        try( TDT_RB_baseTime = (dotNetClass "System.IO.File").GetLastWriteTime fbx )catch()
                        tmrWatch.active = false
                        TDT_RB_CloseRizom()
                        lblStatus.text = "已回传并加 RizomUV_UVs 修改器：" + (n as string) + \
                                         " 个物体，RizomUV 已关闭。"
                    )
                )
            )
        )
    )
)

createDialog TDT_MainTool style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
)
)
