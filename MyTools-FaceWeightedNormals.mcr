
macroScript FaceWeightedNormalsTool
category:"AAA我的工具 (MyTools)"
buttonText:"面加权法线"
toolTip:"面加权法线（按面积加权重算法线，硬表面免卡线）"
--@@ICONNAME@@
(
    on execute do
    (
        try(destroyDialog FWNormals)catch()

-- ============================================================
--  面加权法线（Face Weighted Normals）
--  原理：给选中模型加「编辑法线」修改器，把每个顶点的法线设为
--        相邻面「面法线 × 面面积」的加权平均，再归一化。
--        哪些面在某顶点处融合，由该处的平滑组决定（缝处=硬边）。
-- ============================================================

rollout FWNormals "面加权法线" width:296 height:210
(
    -- 平滑依据（两选一）；offsets 把第二个选项再往下推，避免两行太挤
    radioButtons  rdo_basis labels:#("沿用现有平滑组（按已设硬边/平滑组）", "按角度阈值自动判断硬/软边") default:2 columns:1 offsets:#([0,0],[0,10]) pos:[16,14]
    -- 角度阈值：缩进对齐到上方第二个选项的文字，作为其参数；与微调框垂直居中对齐
    dotNetControl lbl_ang "System.Windows.Forms.Label" pos:[32,74] width:58 height:16
    spinner       spn_angle "" range:[0,180,45] type:#float value:45.0 pos:[92,72] width:70 tooltip:"相邻面夹角大于此角度算硬边、小于算软边（仅‘按角度阈值’时生效）"
    dotNetControl lbl_deg "System.Windows.Forms.Label" pos:[168,74] width:16 height:16

    -- 操作按钮（等宽等高、左边距一致、间距一致）
    dotNetControl btn_gen "System.Windows.Forms.Button" pos:[16,104] width:264 height:40
    dotNetControl btn_rem "System.Windows.Forms.Button" pos:[16,158] width:264 height:40

    -- 防 GC：保留 .NET 字体/位图引用，避免被回收后控件重绘报「参数无效」/ 按钮变红叉
    local gKeep = #()

    -- ── 16×16 按钮图标（透明底 + 橙色挖空，靠按钮黑底显形）──
    fn MakeIcon mode =
    (
        local bmp = undefined
        try
        (
            bmp = dotNetObject "System.Drawing.Bitmap" 16 16
            local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
            local ac = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 236 152 64)
            local sh = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 202 208 216)
            local bk = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 0 0 0)
            case mode of
            (
                -- 生成：底部横板(面) + 向上箭头(法线)
                #gen:   ( g.FillRectangle sh 2 11 12 3; g.FillRectangle ac 7 2 2 8; g.FillRectangle ac 6 3 4 1; g.FillRectangle ac 5 4 6 1; g.FillRectangle ac 7 2 2 1 )
                -- 移除：垃圾桶
                #trash: ( g.FillRectangle ac 2 2 12 2; g.FillRectangle ac 6 0 4 2; g.FillRectangle sh 3 4 10 11; g.FillRectangle bk 5 6 1 7; g.FillRectangle bk 8 6 1 7; g.FillRectangle bk 11 6 1 7 )
                default: ()
            )
            g.Dispose()
        )
        catch ( bmp = undefined )
        bmp
    )

    -- ========================================================
    --  核心算法
    -- ========================================================

    -- 移除本工具之前加的修改器（按名字 FWN- 识别，绝不动用户自己的修改器）
    fn FWN_RemoveOld obj =
    (
        local removed = 0
        try ( for i = obj.modifiers.count to 1 by -1 do
        (
            local m = obj.modifiers[i]
            if (m != undefined) and ((classOf m == Edit_Normals) or (classOf m == Smooth)) \
               and (matchPattern (m.name) pattern:"FWN-*") do
            ( deleteModifier obj i ; removed += 1 )
        ) ) catch ()
        removed
    )

    -- 用牛顿法(Newell)求一个多边形面的单位法线与面积（支持三角面 / 四边面 / N 边面）
    fn FWN_FaceNormalArea obj f =
    (
        local vids = polyop.getFaceVerts obj f
        local c = vids.count
        local nx = 0.0 ; local ny = 0.0 ; local nz = 0.0
        local prev = polyop.getVert obj vids[c]
        for i = 1 to c do
        (
            local cur = polyop.getVert obj vids[i]
            nx += (prev.y - cur.y) * (prev.z + cur.z)
            ny += (prev.z - cur.z) * (prev.x + cur.x)
            nz += (prev.x - cur.x) * (prev.y + cur.y)
            prev = cur
        )
        local nrm = [nx, ny, nz]
        local len = length nrm
        local unit = if len > 1.0e-9 then (nrm / len) else [0,0,1]
        #(unit, len * 0.5)
    )

    -- 为单个物体生成面加权法线。返回 #(成功?, 写入的法线数 或 错误文字)
    fn FWN_Generate obj useAngle angle =
    (
        local res = #(false, "")
        try
        (
            -- 1) 统一为可编辑多边形（非 EPoly 会塌陷堆栈，保证读取的拓扑与编辑法线一致）
            if not (isKindOf obj Editable_Poly) do
            (
                if (canConvertTo obj Editable_Poly) then convertTo obj Editable_Poly
                else return #(false, (obj.name + "：不是可转为可编辑多边形的网格"))
            )

            FWN_RemoveOld obj
            select obj
            max modify mode

            -- 2) 角度模式：在底下加「平滑」修改器(自动平滑)，按角度重建平滑组（不改基础物体）
            if useAngle do
            (
                local sm = Smooth()
                sm.name = "FWN-角度平滑"
                sm.autosmooth = true
                sm.threshold = angle
                addModifier obj sm
            )

            -- 3) 顶部加「编辑法线」
            local en = Edit_Normals()
            en.name = "FWN-面加权法线"
            addModifier obj en
            modPanel.setCurrentObject en

            -- 4) 预存每个多边形面的单位法线与面积
            local nf = polyop.getNumFaces obj
            if nf == 0 do return #(false, (obj.name + "：没有面"))
            local fUnit = #() ; local fArea = #()
            fUnit[nf] = [0,0,1] ; fArea[nf] = 0.0
            for f = 1 to nf do
            (
                local na = FWN_FaceNormalArea obj f
                fUnit[f] = na[1] ; fArea[f] = na[2]
            )

            -- 5) 累加：每个法线 ID = 引用它的各面（面法线 × 面积）之和
            local numN = en.GetNumNormals()
            if numN == 0 do return #(false, (obj.name + "：编辑法线未生成法线"))
            local accum = #() ; accum[numN] = [0,0,0]
            for i = 1 to numN do accum[i] = [0,0,0]

            local enFaces = en.GetNumFaces()
            local fmax = if nf < enFaces then nf else enFaces
            for f = 1 to fmax do
            (
                local w = fUnit[f] * fArea[f]
                local deg = en.GetFaceDegree f
                for cc = 1 to deg do
                (
                    local nid = en.GetNormalId f cc
                    if (nid != undefined) and (nid >= 1) and (nid <= numN) do
                        accum[nid] += w
                )
            )

            -- 6) 写回为显式法线
            local setCnt = 0
            for i = 1 to numN do
            (
                local v = accum[i]
                if (length v) > 1.0e-9 do
                (
                    en.SetNormalExplicit i explicit:true
                    en.SetNormal i (normalize v)
                    setCnt += 1
                )
            )
            update obj
            res = #(true, setCnt)
        )
        catch ( res = #(false, (obj.name + "：" + getCurrentException())) )
        res
    )

    -- ========================================================
    --  参数记忆
    -- ========================================================
    fn FWN_Ini = ( (getDir #plugcfg) + "\\FWNormalsSettings.ini" )
    fn FWN_Load =
    (
        local f = FWN_Ini()
        if not (doesFileExist f) do return false
        fn _g ff key def = ( local v = getINISetting ff "Settings" key ; if v == "" then def else v )
        try ( rdo_basis.state = (_g f "basis" "2") as integer ) catch()
        try ( spn_angle.value = (_g f "angle" "45.0") as float ) catch()
        true
    )
    fn FWN_Save =
    (
        local f = FWN_Ini()
        try ( setINISetting f "Settings" "basis" (rdo_basis.state as string) ) catch()
        try ( setINISetting f "Settings" "angle" (spn_angle.value as string) ) catch()
    )

    -- ========================================================
    --  事件
    -- ========================================================
    on FWNormals open do
    (
        local flatF   = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
        local fntUI   = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 9
        local fntBig  = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 10 ((dotNetClass "System.Drawing.FontStyle").Bold)
        append gKeep fntUI ; append gKeep fntBig
        try ( dotNet.setLifetimeControl fntUI #dotnet ) catch ()
        try ( dotNet.setLifetimeControl fntBig #dotnet ) catch ()

        local leftAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
        local cBtn    = ((dotNetClass "System.Drawing.Color").FromArgb 0 0 0)         -- 按钮纯黑底
        local cBtnTxt = ((dotNetClass "System.Drawing.Color").FromArgb 202 208 216)   -- 按钮浅灰字
        local clrLbl  = ((dotNetClass "System.Drawing.Color").FromArgb 150 168 195)   -- 标注 蓝灰字
        local clrBg   = ((dotNetClass "System.Drawing.Color").FromArgb 56 56 56)      -- 面板底色(兜底)
        try (
            local bg = colorMan.getColor #background
            clrBg = (dotNetClass "System.Drawing.Color").FromArgb ((bg.x*255.0) as integer) ((bg.y*255.0) as integer) ((bg.z*255.0) as integer)
        ) catch ()

        -- AutoSize=false：固定尺寸，避免标签按文字自动撑大、压到按钮导致点不动
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

        _styleLbl lbl_ang "角度阈值" clrLbl clrBg fntUI leftAlign
        _styleLbl lbl_deg "°"        clrLbl clrBg fntUI leftAlign

        _styleBtn btn_gen "生成面加权法线" cBtn flatF cBtnTxt fntBig
        _styleBtn btn_rem "移除加权法线"   cBtn flatF cBtnTxt fntUI
        _setIcon  btn_gen #gen
        _setIcon  btn_rem #trash

        -- 悬停提示
        try
        (
            local tt = dotNetObject "System.Windows.Forms.ToolTip"
            tt.InitialDelay = 350 ; tt.AutoPopDelay = 15000 ; tt.ReshowDelay = 200 ; tt.ShowAlways = true
            append gKeep tt
            tt.SetToolTip btn_gen "给选中的每个网格物体加『编辑法线』修改器，按相邻面面积加权写入法线。可重复点击（自动替换旧的）。\n注意：编辑网格 / 改平滑组后需重新生成；非可编辑多边形会先转为可编辑多边形。"
            tt.SetToolTip btn_rem "删除本工具之前给选中模型加的『FWN-』修改器，恢复原始法线。"
        ) catch ()

        -- 角度阈值仅在『按角度阈值』模式下可用
        try ( FWN_Load() ) catch ()
        spn_angle.enabled = (rdo_basis.state == 2)
    )

    on FWNormals close do ( try ( FWN_Save() ) catch () )

    on rdo_basis changed st do ( spn_angle.enabled = (st == 2) )

    on btn_gen click do
    (
        local objs = for o in (getCurrentSelection()) \
                     where (superClassOf o == GeometryClass) and (not (isKindOf o BoneGeometry)) and (not (isKindOf o Biped_Object)) \
                     collect o
        if objs.count == 0 then ( messageBox "请先选中至少一个网格物体！" title:"提示" ; return() )

        local useAngle = (rdo_basis.state == 2)
        local ang = spn_angle.value
        local okN = 0 ; local failN = 0 ; local totalSet = 0 ; local lastErr = ""
        undo "生成面加权法线" on
        (
            for obj in objs do
            (
                local r = FWN_Generate obj useAngle ang
                if r[1] then ( okN += 1 ; totalSet += r[2] ) else ( failN += 1 ; lastErr = r[2] )
            )
        )
        try ( select objs ) catch ()

        local msg = "√ 已为 " + okN as string + " 个物体生成面加权法线"
        msg += if useAngle then ("（按角度阈值 " + ang as string + "°）") else "（沿用现有平滑组）"
        if failN > 0 then msg += "\n× " + failN as string + " 个失败，最后一条：\n" + lastErr
        messageBox msg title:"完成"
    )

    on btn_rem click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选中物体！" title:"提示" ; return() )
        local n = 0
        undo "移除面加权法线" on ( for obj in objs do n += FWN_RemoveOld obj )
        messageBox ("√ 已移除 " + n as string + " 个本工具添加的修改器（FWN-）。") title:"完成"
    )
)

createDialog FWNormals

    )
)
