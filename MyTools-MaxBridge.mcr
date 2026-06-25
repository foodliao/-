
macroScript MaxBridgeTool
category:"AAA我的工具 (MyTools)"
buttonText:"Max桥接"
toolTip:"Max 桥接 Maya / Blender：把选中模型 / 整个场景保真发送过去"
--@@ICONNAME@@
(
    on execute do
    (
        try(destroyDialog MaxBridge)catch()

rollout MaxBridge "Max 桥接 Maya / Blender 工具" width:344 height:278
(
    -- ① 发送内容与选项 ------------------------------------------
    dotNetControl hdr1 "System.Windows.Forms.Button" pos:[12,10] width:320 height:24
    radioButtons  rdo_scope labels:#("仅选中物体","整个场景") default:1 columns:2 pos:[20,42] width:300 \
        tooltip:"仅选中物体：只发送当前选中的网格；整个场景：发送场景里所有可导出物体。"
    checkbox      chk_embed "嵌入贴图（材质随行）" pos:[20,70]  width:175 checked:true \
        tooltip:"把贴图直接打包进 FBX，材质随模型一起过去（文件略大）。关闭则只带材质槽、贴图按原路径链接。"
    checkbox      chk_anim  "包含动画"             pos:[200,70] width:132 checked:false \
        tooltip:"导出关键帧动画（默认关；静帧模型更快更干净）。"
    checkbox      chk_skin  "包含蒙皮 / Morph"     pos:[20,94]  width:175 checked:true \
        tooltip:"导出蒙皮(Skin)与形态键(Morph / BlendShape)。"
    checkbox      chk_caml  "包含摄像机 / 灯光"    pos:[200,94] width:132 checked:false \
        tooltip:"连同摄像机与灯光一起导出（默认关）。"
    dotNetControl lbl_fbx "System.Windows.Forms.Label" pos:[20,120] width:64 height:18
    dropdownlist  ddl_fbx "" pos:[86,117] width:160 \
        tooltip:"FBX 文件格式版本。默认 FBX 2014 兼容性最高（Maya 2014+ 与各版本 Blender 都能读）；发到很新的软件可调高。\n注意：用来导出的 Max 版本太老时，过新的格式会自动回退到它能写的最高档。"
    dotNetControl lbl_note "System.Windows.Forms.Label" pos:[20,146] width:312 height:18

    -- ② 发送到 Maya / Blender（版本下拉 + 发送按钮同排，省空间）------
    dotNetControl hdr2 "System.Windows.Forms.Button" pos:[12,170] width:320 height:24
    dropdownlist  ddl_maya "" pos:[20,205] width:168 \
        tooltip:"选择要打开的 Maya 版本；选『浏览自定义…』可手动指定 maya.exe。"
    dotNetControl btn_maya "System.Windows.Forms.Button" pos:[196,201] width:136 height:28
    dropdownlist  ddl_bl "" pos:[20,239] width:168 \
        tooltip:"选择要打开的 Blender 版本；选『浏览自定义…』可手动指定 blender.exe。"
    dotNetControl btn_bl "System.Windows.Forms.Button" pos:[196,235] width:136 height:28

    -- 防 GC：保留 .NET 字体/位图/提示引用，避免被回收后控件重绘报「参数无效」/ 图标变红叉
    local gKeep = #()
    -- 检测到的版本列表：每项 #(显示名, exe路径, 排序键)
    local mayaList  = #()
    local blendList = #()
    local mayaCustom  = ""    -- 浏览自定义指定的 maya.exe
    local blendCustom = ""    -- 浏览自定义指定的 blender.exe
    -- FBX 格式档：每项 #(显示名, FileVersion 串)。默认第 1 项 FBX2014 兼容性最高
    local fbxVers = #( \
        #("FBX 2014（最大兼容）", "FBX201400"), \
        #("FBX 2016", "FBX201600"), \
        #("FBX 2018（通用）", "FBX201800"), \
        #("FBX 2020（最新）", "FBX202000") )

    -- ── 16×16 按钮图标（透明底 + 橙色箭头，靠按钮黑底显形）──
    fn MakeIcon mode =
    (
        local bmp = undefined
        try
        (
            bmp = dotNetObject "System.Drawing.Bitmap" 16 16
            local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
            try ( g.SmoothingMode = (dotNetClass "System.Drawing.Drawing2D.SmoothingMode").AntiAlias ) catch ()
            g.Clear ((dotNetClass "System.Drawing.Color").Transparent)
            local cAcc = (dotNetClass "System.Drawing.Color").FromArgb 255 236 152 64
            local cBox = (dotNetClass "System.Drawing.Color").FromArgb 255 120 165 205
            case mode of
            (
                -- 发送：左侧方盒(模型) + 向右橙色箭头
                #send: (
                    local brBox = dotNetObject "System.Drawing.SolidBrush" cBox
                    g.FillRectangle brBox 1.0 5.0 6.0 6.0
                    local pen = dotNetObject "System.Drawing.Pen" cAcc 2.4
                    try ( pen.StartCap = (dotNetClass "System.Drawing.Drawing2D.LineCap").Round ) catch ()
                    try ( pen.CustomEndCap = dotNetObject "System.Drawing.Drawing2D.AdjustableArrowCap" 2.6 2.6 ) catch ()
                    g.DrawLine pen 8.0 8.0 14.0 8.0
                )
                default: ()
            )
            g.Dispose()
        )
        catch ( bmp = undefined )
        bmp
    )

    -- ========================================================
    --  软件检测
    -- ========================================================
    fn _verDigits nm withDot =
    (
        local out = ""
        for i = 1 to nm.count do
        (
            local ch = nm[i]
            if (ch >= "0" and ch <= "9") then out += ch
            else if withDot and ch == "." do out += ch
        )
        out
    )

    fn _descByKey a b = ( if a[3] > b[3] then -1 else if a[3] < b[3] then 1 else 0 )

    fn DetectMaya =
    (
        local out = #()
        local dirCls  = dotNetClass "System.IO.Directory"
        local pathCls = dotNetClass "System.IO.Path"
        local pf = (dotNetClass "System.Environment").GetEnvironmentVariable "ProgramFiles"
        if pf == undefined or pf == "" do pf = "C:\\Program Files"
        local adsk = pf + "\\Autodesk"
        if (dirCls.Exists adsk) do for d in (dirCls.GetDirectories adsk) do
        (
            try
            (
                local nm = pathCls.GetFileName d
                if (matchPattern nm pattern:"Maya2*") do
                (
                    local exe = d + "\\bin\\maya.exe"
                    if (doesFileExist exe) do
                    (
                        local yr = 0
                        try ( yr = (_verDigits nm false) as integer ) catch ()
                        append out #(("Maya " + (substring nm 5 -1)), exe, (yr as float))
                    )
                )
            ) catch ()
        )
        qsort out _descByKey
        out
    )

    fn DetectBlender =
    (
        local out = #()
        local dirCls  = dotNetClass "System.IO.Directory"
        local pathCls = dotNetClass "System.IO.Path"
        local roots = #()
        local pf = (dotNetClass "System.Environment").GetEnvironmentVariable "ProgramFiles"
        if pf != undefined do append roots (pf + "\\Blender Foundation")
        local up = (dotNetClass "System.Environment").GetEnvironmentVariable "USERPROFILE"
        if up != undefined do append roots (up + "\\BlenderVersions")
        for r in roots where (dirCls.Exists r) do for d in (dirCls.GetDirectories r) do
        (
            try
            (
                local nm = pathCls.GetFileName d
                local exe = d + "\\blender.exe"
                if (doesFileExist exe) do
                (
                    local vf = 0.0
                    try ( vf = (_verDigits nm true) as float ) catch ()
                    append out #(nm, exe, vf)
                )
            ) catch ()
        )
        qsort out _descByKey
        out
    )

    -- 重建下拉项（检测到的版本 + 末项「浏览自定义…」或已选的自定义路径）
    fn RefreshItems ddl lst custom =
    (
        local items = for e in lst collect e[1]
        local lastLbl = if custom != "" then ("自定义：" + custom) else "浏览自定义…"
        append items lastLbl
        ddl.items = items
    )

    fn ResolveExe ddl lst custom =
    (
        local i = ddl.selection
        local exe = undefined
        if i >= 1 and i <= lst.count then exe = lst[i][2]
        else if custom != "" and (doesFileExist custom) then exe = custom
        exe
    )

    fn SelectByLabel ddl lbl =
    (
        if lbl != "" do ( local idx = findItem ddl.items lbl ; if idx > 0 do ddl.selection = idx )
    )

    -- ========================================================
    --  导出 / 启动
    -- ========================================================
    fn BridgeWorkDir =
    (
        local wd = undefined
        try
        (
            local la = (dotNetClass "System.Environment").GetEnvironmentVariable "LOCALAPPDATA"
            if la == undefined or la == "" do la = (getDir #temp)
            wd = la + "\\Temp\\MaxBridge"
            local dirCls = dotNetClass "System.IO.Directory"
            if not (dirCls.Exists wd) do dirCls.CreateDirectory wd
        )
        catch ( wd = undefined )
        wd
    )

    fn BridgeExportFBX fbx selOnly =
    (
        local ok = false
        try
        (
            fn _fs k v = ( try ( FBXExporterSetParam k v ) catch () )
            try ( FBXExporterSetParam "ResetExport" ) catch ()
            -- FBX 格式版本（用户可选，默认最兼容 FBX2014）；过新档若本机 Max 不支持，try 跳过后用默认
            local fv = "FBX201400"
            try ( if ddl_fbx.selection >= 1 and ddl_fbx.selection <= fbxVers.count do fv = fbxVers[ddl_fbx.selection][2] ) catch ()
            _fs "FileVersion" fv
            _fs "ASCII" false
            _fs "EmbedTextures" (chk_embed.checked)
            _fs "Materials" true
            _fs "Animation" (chk_anim.checked)
            _fs "Skins" (chk_skin.checked)
            _fs "Shapes" (chk_skin.checked)
            _fs "Cameras" (chk_caml.checked)
            _fs "Lights" (chk_caml.checked)
            -- 保真：原样保留 平滑组 / 法线 / 点线面（不三角化）/ 边 / 实例 / 比例
            _fs "SmoothingGroups" true              -- 导出平滑组（硬/软边）
            _fs "NormalsPerPoly" false              -- 正常导出法线
            _fs "Triangulate" false                 -- 不三角化：四边/N 边面原样保留
            _fs "PreserveEdgeOrientation" true      -- 保留边的朝向/结构
            _fs "Preserveinstances" true            -- 实例仍是实例（共享网格）
            _fs "SmoothMeshExport" false            -- 不把网格当细分面再细分
            _fs "TangentSpaceExport" false          -- 不额外生成切线（目标端按需重算，避免裂点）
            _fs "ConvertUnit" "cm"                  -- 单位锁 cm（Maya 原生 cm，1:1 不缩放）
            _fs "UpAxis" "Y"                        -- FBX 标准 Y-up（Maya 原生 / Blender 自动转 Z）
            ok = exportFile fbx #noPrompt selectedOnly:selOnly using:FBXEXP
        )
        catch ( ok = false )
        ok
    )

    fn LaunchBlender exe fbx wd stamp =
    (
        local ok = false
        try
        (
            local fbxFwd = substituteString fbx "\\" "/"
            local pyPath = wd + "\\bridge_" + stamp + ".py"
            local nl = "\n"
            -- use_custom_normals=True 保留平滑组/法线；老版本不认该参数则回退
            local py = "import bpy" + nl + \
                "fp = r\"" + fbxFwd + "\"" + nl + \
                "try:" + nl + \
                "    try:" + nl + \
                "        bpy.ops.import_scene.fbx(filepath=fp, use_custom_normals=True)" + nl + \
                "    except TypeError:" + nl + \
                "        bpy.ops.import_scene.fbx(filepath=fp)" + nl + \
                "    print('[MaxBridge] imported:', fp)" + nl + \
                "except Exception as e:" + nl + \
                "    print('[MaxBridge] import failed:', e)" + nl
            local fenc = dotNetObject "System.Text.UTF8Encoding" false
            (dotNetClass "System.IO.File").WriteAllText pyPath py fenc
            local args = "--python \"" + pyPath + "\""
            local psi = dotNetObject "System.Diagnostics.ProcessStartInfo" exe args
            psi.UseShellExecute = true
            try ( psi.WorkingDirectory = (getFilenamePath exe) ) catch ()
            (dotNetClass "System.Diagnostics.Process").Start psi
            ok = true
        )
        catch ( ok = false )
        ok
    )

    fn LaunchMaya exe fbx wd stamp =
    (
        local ok = false
        try
        (
            local fbxFwd  = substituteString fbx "\\" "/"
            local melPath = wd + "\\bridge_" + stamp + ".mel"
            local melFwd  = substituteString melPath "\\" "/"
            local nl = "\n"
            local mel = "if (!`pluginInfo -q -loaded \"fbxmaya\"`) loadPlugin \"fbxmaya\";" + nl + \
                "evalDeferred(\"FBXImport -f \\\"" + fbxFwd + "\\\";\");" + nl
            local fenc = dotNetObject "System.Text.UTF8Encoding" false
            (dotNetClass "System.IO.File").WriteAllText melPath mel fenc
            local args = "-command \"source \\\"" + melFwd + "\\\"\""
            -- 强制 DirectX 视口设备，规避「颜色管理：未能完成颜色变换」弹窗（远程/某些显卡的 OpenGL 颜色变换失败）。
            -- 在 Max 进程里设环境变量，子进程(Maya)继承；不改 UseShellExecute，零副作用。
            try ( (dotNetClass "System.Environment").SetEnvironmentVariable "MAYA_OGS_DEVICE_OVERRIDE" "VirtualDeviceDx11" ) catch ()
            local psi = dotNetObject "System.Diagnostics.ProcessStartInfo" exe args
            psi.UseShellExecute = true
            try ( psi.WorkingDirectory = (getFilenamePath exe) ) catch ()
            (dotNetClass "System.Diagnostics.Process").Start psi
            ok = true
        )
        catch ( ok = false )
        ok
    )

    fn DoSend target =
    (
        local exe = undefined
        local tname = ""
        if target == #maya then ( exe = ResolveExe ddl_maya mayaList mayaCustom ; tname = "Maya" )
        else ( exe = ResolveExe ddl_bl blendList blendCustom ; tname = "Blender" )

        if exe == undefined or not (doesFileExist exe) do
        (
            messageBox ("未找到 " + tname + " 可执行文件。\n请在「版本」下拉里选择已安装版本，或选「浏览自定义…」手动指定 " + (toLower tname) + ".exe。") title:"提示"
            return false
        )

        local selOnly = (rdo_scope.state == 1)
        if selOnly and selection.count == 0 do
        (
            messageBox "请先选中至少一个物体；或把「发送范围」改为「整个场景」。" title:"提示"
            return false
        )

        local wd = BridgeWorkDir()
        if wd == undefined do ( messageBox "无法创建临时工作目录。" title:"失败" ; return false )

        local now = (dotNetClass "System.DateTime").Now
        local stamp = now.ToString "yyyyMMdd_HHmmss"
        local fbx = wd + "\\bridge_" + stamp + ".fbx"

        if not (BridgeExportFBX fbx selOnly) do
        ( messageBox "× FBX 导出失败（FBX 插件不可用或导出被中断）。" title:"失败" ; return false )
        if (not (doesFileExist fbx)) or ((getFileSize fbx) <= 0) do
        ( messageBox "× 导出的 FBX 为空，未生成模型。\n请确认选择 / 场景里有可导出的网格物体。" title:"失败" ; return false )

        local launched = false
        if target == #maya then launched = LaunchMaya exe fbx wd stamp
        else launched = LaunchBlender exe fbx wd stamp

        if launched then
            messageBox ("√ 已导出并启动 " + tname + " 自动导入。\n\n· 每次发送都会新开一个 " + tname + " 窗口，\n  首次启动较慢请稍候，模型会自动导入进去。\n· FBX 文件：\n" + fbx) title:("已发送到 " + tname)
        else
            messageBox ("× 启动 " + tname + " 失败，请检查 exe 路径是否正确。") title:"失败"
        launched
    )

    -- ========================================================
    --  参数记忆
    -- ========================================================
    fn IniPath = ( (getDir #plugcfg) + "\\MaxBridge.ini" )

    fn LoadIni =
    (
        local f = IniPath()
        if not (doesFileExist f) do return false
        fn _g ff key def = ( local v = getINISetting ff "Settings" key ; if v == "" then def else v )
        try ( rdo_scope.state = (_g f "scope" "1") as integer ) catch ()
        try ( chk_embed.checked = ((_g f "embed" "true")  == "true") ) catch ()
        try ( chk_anim.checked  = ((_g f "anim"  "false") == "true") ) catch ()
        try ( chk_skin.checked  = ((_g f "skin"  "true")  == "true") ) catch ()
        try ( chk_caml.checked  = ((_g f "caml"  "false") == "true") ) catch ()
        try ( ddl_fbx.selection = (_g f "fbx_sel" "1") as integer ) catch ()
        mayaCustom  = _g f "maya_custom" ""
        blendCustom = _g f "blend_custom" ""
        RefreshItems ddl_maya mayaList  mayaCustom
        RefreshItems ddl_bl   blendList blendCustom
        try ( SelectByLabel ddl_maya (_g f "maya_sel" "") ) catch ()
        try ( SelectByLabel ddl_bl   (_g f "blend_sel" "") ) catch ()
        true
    )

    fn SaveIni =
    (
        local f = IniPath()
        try ( setINISetting f "Settings" "scope" (rdo_scope.state as string) ) catch ()
        try ( setINISetting f "Settings" "embed" (chk_embed.checked as string) ) catch ()
        try ( setINISetting f "Settings" "anim"  (chk_anim.checked  as string) ) catch ()
        try ( setINISetting f "Settings" "skin"  (chk_skin.checked  as string) ) catch ()
        try ( setINISetting f "Settings" "caml"  (chk_caml.checked  as string) ) catch ()
        try ( setINISetting f "Settings" "fbx_sel" (ddl_fbx.selection as string) ) catch ()
        try ( setINISetting f "Settings" "maya_custom"  mayaCustom )  catch ()
        try ( setINISetting f "Settings" "blend_custom" blendCustom ) catch ()
        try ( setINISetting f "Settings" "maya_sel"  (if ddl_maya.selection >= 1 then ddl_maya.items[ddl_maya.selection] else "") ) catch ()
        try ( setINISetting f "Settings" "blend_sel" (if ddl_bl.selection   >= 1 then ddl_bl.items[ddl_bl.selection]     else "") ) catch ()
    )

    -- ========================================================
    --  事件
    -- ========================================================
    on MaxBridge open do
    (
        local flatF   = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
        local fntUI   = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 9
        local fntBig  = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 10 ((dotNetClass "System.Drawing.FontStyle").Bold)
        local fntHdr  = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 11 ((dotNetClass "System.Drawing.FontStyle").Bold)
        append gKeep fntUI ; append gKeep fntBig ; append gKeep fntHdr
        try ( dotNet.setLifetimeControl fntUI  #dotnet ) catch ()
        try ( dotNet.setLifetimeControl fntBig #dotnet ) catch ()
        try ( dotNet.setLifetimeControl fntHdr #dotnet ) catch ()

        local leftAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
        local midAlign  = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        local cBtn     = ((dotNetClass "System.Drawing.Color").FromArgb 0 0 0)         -- 按钮纯黑底
        local cBtnTxt  = ((dotNetClass "System.Drawing.Color").FromArgb 202 208 216)   -- 按钮浅灰字
        local clrLbl   = ((dotNetClass "System.Drawing.Color").FromArgb 150 168 195)   -- 标注 蓝灰字
        local clrTxt   = ((dotNetClass "System.Drawing.Color").FromArgb 240 240 240)   -- 标题条 白字
        local clrBg    = ((dotNetClass "System.Drawing.Color").FromArgb 56 56 56)      -- 面板底色(兜底)
        try (
            local bg = colorMan.getColor #background
            clrBg = (dotNetClass "System.Drawing.Color").FromArgb ((bg.x*255.0) as integer) ((bg.y*255.0) as integer) ((bg.z*255.0) as integer)
        ) catch ()

        fn _mkClr r g b = ((dotNetClass "System.Drawing.Color").FromArgb r g b)

        fn _styleLbl L txt foreCol bgCol fnt leftAlign =
        ( try ( L.AutoSize=false; L.text=txt; L.backColor=bgCol; L.foreColor=foreCol; L.font=fnt; L.textAlign=leftAlign ) catch () )

        fn _styleBtn b txt col flatF txtCol fnt =
        (
            try ( b.text = txt ) catch ()
            try
            (
                b.flatStyle = flatF
                b.useVisualStyleBackColor = false
                b.backColor = col
                b.foreColor = txtCol
                b.font      = fnt
                b.flatAppearance.borderSize  = 1
                b.flatAppearance.borderColor = ((dotNetClass "System.Drawing.Color").FromArgb 90 90 90)
                b.flatAppearance.MouseOverBackColor = ((dotNetClass "System.Drawing.Color").FromArgb 88 88 88)
                b.flatAppearance.MouseDownBackColor = ((dotNetClass "System.Drawing.Color").FromArgb 122 122 122)
            ) catch ()
        )

        fn _styleHdr h txt col clrText fntHdr midAlign =
        (
            try ( h.text = txt ) catch ()
            try ( h.backColor=col; h.foreColor=clrText; h.font=fntHdr; h.textAlign=midAlign ) catch ()
            try
            (
                h.flatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                h.useVisualStyleBackColor = false
                h.flatAppearance.borderSize = 0
                h.flatAppearance.MouseOverBackColor = col
                h.flatAppearance.MouseDownBackColor = col
            ) catch ()
        )

        fn _setIcon b mode =
        (
            try (
                local ic = MakeIcon mode
                if ic != undefined do
                (
                    append gKeep ic
                    try ( dotNet.setLifetimeControl ic #dotnet ) catch ()
                    b.Image = ic
                    b.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    b.TextAlign  = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    b.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageBeforeText
                    try (
                        local tsz = (dotNetClass "System.Windows.Forms.TextRenderer").MeasureText b.text b.Font
                        local pad = ((b.Width - 16 - tsz.Width) / 4.0)
                        if pad < 0.0 do pad = 0.0
                        b.Padding = dotNetObject "System.Windows.Forms.Padding" (pad as integer) 0 0 0
                    ) catch ()
                )
            ) catch ()
        )

        -- 彩色粗体标题条（只保留两个：内容/选项 + 发送目标）
        _styleHdr hdr1 "①  选择发送范围和内容"        (_mkClr 86 122 170) clrTxt fntHdr midAlign
        _styleHdr hdr2 "②  发送到 Maya / Blender"   (_mkClr 84 134 154) clrTxt fntHdr midAlign

        _styleLbl lbl_fbx  "FBX 格式" clrLbl clrBg fntUI leftAlign
        _styleLbl lbl_note "✓ 原样保留：平滑组 · 点线面（不三角化）· 位置 / 比例" clrLbl clrBg fntUI leftAlign

        _styleBtn btn_maya "发送到 Maya"    cBtn flatF cBtnTxt fntBig
        _styleBtn btn_bl   "发送到 Blender" cBtn flatF cBtnTxt fntBig
        _setIcon  btn_maya #send
        _setIcon  btn_bl   #send

        -- 填充 FBX 格式下拉（默认第 1 项 = 最兼容）
        ddl_fbx.items = (for v in fbxVers collect v[1])
        ddl_fbx.selection = 1

        -- 检测安装的版本，填充下拉
        mayaList  = DetectMaya()
        blendList = DetectBlender()
        RefreshItems ddl_maya mayaList  mayaCustom
        RefreshItems ddl_bl   blendList blendCustom

        -- 悬停提示
        try
        (
            local tt = dotNetObject "System.Windows.Forms.ToolTip"
            tt.InitialDelay = 350 ; tt.AutoPopDelay = 15000 ; tt.ReshowDelay = 200 ; tt.ShowAlways = true
            append gKeep tt
            tt.SetToolTip btn_maya "把当前选择 / 整个场景导出为内嵌贴图 FBX，并启动选定版本的 Maya 自动导入（每次新开一个 Maya 窗口）。\n保真：平滑组、法线、点线面（不三角化、不焊点）、位置 / 比例 原样保留；导入用 fbxmaya 插件。\n首次启动较慢属正常。"
            tt.SetToolTip btn_bl   "把当前选择 / 整个场景导出为内嵌贴图 FBX，并启动选定版本的 Blender 自动导入（每次新开一个 Blender 窗口）。\n保真：平滑组转为锐边 + 自定义法线、点线面（不三角化）、位置 / 比例 原样保留；导入到默认场景。"
        ) catch ()

        try ( LoadIni() ) catch ()
    )

    on MaxBridge close do ( try ( SaveIni() ) catch () )

    on ddl_maya selected i do
    (
        if i == (mayaList.count + 1) do
        (
            local f = getOpenFileName caption:"选择 maya.exe" types:"Maya 可执行文件|maya.exe|所有 exe|*.exe|"
            if f != undefined and (doesFileExist f) then
            ( mayaCustom = f ; RefreshItems ddl_maya mayaList mayaCustom ; ddl_maya.selection = (mayaList.count + 1) )
            else ( ddl_maya.selection = 1 )
        )
    )

    on ddl_bl selected i do
    (
        if i == (blendList.count + 1) do
        (
            local f = getOpenFileName caption:"选择 blender.exe" types:"Blender 可执行文件|blender.exe|所有 exe|*.exe|"
            if f != undefined and (doesFileExist f) then
            ( blendCustom = f ; RefreshItems ddl_bl blendList blendCustom ; ddl_bl.selection = (blendList.count + 1) )
            else ( ddl_bl.selection = 1 )
        )
    )

    on btn_maya click do ( DoSend #maya )
    on btn_bl   click do ( DoSend #blender )
)

createDialog MaxBridge

    )
)
