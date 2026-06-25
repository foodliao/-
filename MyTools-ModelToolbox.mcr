
macroScript ModelToolboxTool
category:"AAA我的工具 (MyTools)"
buttonText:"模型批量整理工具"
toolTip:"模型批量整理工具（批量整理 / 检查 / 导出）"
--@@ICONNAME@@
(
    on execute do
    (
        try(destroyDialog ModelToolbox)catch()

-- ============================================================
--  模型一键整理导出工具
--  分区：批量导入 / 模型修复 / 规范检查 / 场景清理 / 批量导出
-- ============================================================

rollout ModelToolbox "模型批量整理工具" width:324 height:1100
(
    -- 分组描边：每组用 4 条 1px 细线拼成方框（白色），只占边缘空隙、不遮挡控件
    dotNetControl g1t "System.Windows.Forms.Panel" pos:[8,94]    width:308 height:1
    dotNetControl g1b "System.Windows.Forms.Panel" pos:[8,158]   width:308 height:1
    dotNetControl g1l "System.Windows.Forms.Panel" pos:[8,94]    width:1   height:64
    dotNetControl g1r "System.Windows.Forms.Panel" pos:[315,94]  width:1   height:64
    dotNetControl g2t "System.Windows.Forms.Panel" pos:[8,275]   width:308 height:1
    dotNetControl g2b "System.Windows.Forms.Panel" pos:[8,336]   width:308 height:1
    dotNetControl g2l "System.Windows.Forms.Panel" pos:[8,275]   width:1   height:61
    dotNetControl g2r "System.Windows.Forms.Panel" pos:[315,275] width:1   height:61
    dotNetControl g3t "System.Windows.Forms.Panel" pos:[8,582]   width:308 height:1
    dotNetControl g3b "System.Windows.Forms.Panel" pos:[8,640]   width:308 height:1
    dotNetControl g3l "System.Windows.Forms.Panel" pos:[8,582]   width:1   height:58
    dotNetControl g3r "System.Windows.Forms.Panel" pos:[315,582] width:1   height:58
    dotNetControl g4t "System.Windows.Forms.Panel" pos:[8,456]   width:308 height:1
    dotNetControl g4b "System.Windows.Forms.Panel" pos:[8,534]   width:308 height:1
    dotNetControl g4l "System.Windows.Forms.Panel" pos:[8,456]   width:1   height:78
    dotNetControl g4r "System.Windows.Forms.Panel" pos:[315,456] width:1   height:78
    dotNetControl g5t "System.Windows.Forms.Panel" pos:[8,904]   width:308 height:1
    dotNetControl g5b "System.Windows.Forms.Panel" pos:[8,1083]  width:308 height:1
    dotNetControl g5l "System.Windows.Forms.Panel" pos:[8,904]   width:1   height:179
    dotNetControl g5r "System.Windows.Forms.Panel" pos:[315,904] width:1   height:179
    dotNetControl g6t "System.Windows.Forms.Panel" pos:[8,716]   width:308 height:1
    dotNetControl g6b "System.Windows.Forms.Panel" pos:[8,770]   width:308 height:1
    dotNetControl g6l "System.Windows.Forms.Panel" pos:[8,716]   width:1   height:54
    dotNetControl g6r "System.Windows.Forms.Panel" pos:[315,716] width:1   height:54
    dotNetControl g7t "System.Windows.Forms.Panel" pos:[8,774]   width:308 height:1
    dotNetControl g7b "System.Windows.Forms.Panel" pos:[8,828]   width:308 height:1
    dotNetControl g7l "System.Windows.Forms.Panel" pos:[8,774]   width:1   height:54
    dotNetControl g7r "System.Windows.Forms.Panel" pos:[315,774] width:1   height:54
    -- 独立按钮外框：导入区(标签+按钮)/旋转行/轴心/重置/修复法线/检查多边面/删除杂物/选择导出目录
    dotNetControl g8t "System.Windows.Forms.Panel" pos:[8,34]    width:308 height:1
    dotNetControl g8b "System.Windows.Forms.Panel" pos:[8,88]    width:308 height:1
    dotNetControl g8l "System.Windows.Forms.Panel" pos:[8,34]    width:1   height:54
    dotNetControl g8r "System.Windows.Forms.Panel" pos:[315,34]  width:1   height:54
    dotNetControl g9t "System.Windows.Forms.Panel" pos:[8,166]   width:308 height:1
    dotNetControl g9b "System.Windows.Forms.Panel" pos:[8,198]   width:308 height:1
    dotNetControl g9l "System.Windows.Forms.Panel" pos:[8,166]   width:1   height:32
    dotNetControl g9r "System.Windows.Forms.Panel" pos:[315,166] width:1   height:32
    dotNetControl g10t "System.Windows.Forms.Panel" pos:[8,238]   width:308 height:1
    dotNetControl g10b "System.Windows.Forms.Panel" pos:[8,270]   width:308 height:1
    dotNetControl g10l "System.Windows.Forms.Panel" pos:[8,238]   width:1   height:32
    dotNetControl g10r "System.Windows.Forms.Panel" pos:[315,238] width:1   height:32
    dotNetControl g11t "System.Windows.Forms.Panel" pos:[8,344]   width:308 height:1
    dotNetControl g11b "System.Windows.Forms.Panel" pos:[8,376]   width:308 height:1
    dotNetControl g11l "System.Windows.Forms.Panel" pos:[8,344]   width:1   height:32
    dotNetControl g11r "System.Windows.Forms.Panel" pos:[315,344] width:1   height:32
    dotNetControl g12t "System.Windows.Forms.Panel" pos:[8,384]   width:308 height:1
    dotNetControl g12b "System.Windows.Forms.Panel" pos:[8,416]   width:308 height:1
    dotNetControl g12l "System.Windows.Forms.Panel" pos:[8,384]   width:1   height:32
    dotNetControl g12r "System.Windows.Forms.Panel" pos:[315,384] width:1   height:32
    dotNetControl g13t "System.Windows.Forms.Panel" pos:[8,542]   width:308 height:1
    dotNetControl g13b "System.Windows.Forms.Panel" pos:[8,574]   width:308 height:1
    dotNetControl g13l "System.Windows.Forms.Panel" pos:[8,542]   width:1   height:32
    dotNetControl g13r "System.Windows.Forms.Panel" pos:[315,542] width:1   height:32
    dotNetControl g14t "System.Windows.Forms.Panel" pos:[8,680]   width:308 height:1
    dotNetControl g14b "System.Windows.Forms.Panel" pos:[8,712]   width:308 height:1
    dotNetControl g14l "System.Windows.Forms.Panel" pos:[8,680]   width:1   height:32
    dotNetControl g14r "System.Windows.Forms.Panel" pos:[315,680] width:1   height:32
    dotNetControl g15t "System.Windows.Forms.Panel" pos:[8,868]   width:308 height:1
    dotNetControl g15b "System.Windows.Forms.Panel" pos:[8,900]   width:308 height:1
    dotNetControl g15l "System.Windows.Forms.Panel" pos:[8,868]   width:1   height:32
    dotNetControl g15r "System.Windows.Forms.Panel" pos:[315,868] width:1   height:32

    -- 辅助工具（批量导入 / 等比缩放 / 90°旋转）
    dotNetControl hdr_aux "System.Windows.Forms.Button" pos:[12,10] width:300 height:22
    dotNetControl lbl_import_tip "System.Windows.Forms.Label" pos:[12,38] width:300 height:14
    dotNetControl btn_import "System.Windows.Forms.Button" pos:[12,56] width:300 height:28
    dotNetControl lbl_th "System.Windows.Forms.Label" pos:[12,102] width:62 height:16
    spinner spn_height "" range:[0.0001,1000000,1.0] type:#float value:1.0 pos:[76,100] width:74 tooltip:"目标高度数值，配合右侧单位与‘识别高度’使用"
    dropdownlist ddl_hunit "" items:#("m", "cm", "mm") selection:1 pos:[156,98] width:58
    dotNetControl btn_getheight "System.Windows.Forms.Button" pos:[218,99] width:92 height:22
    dotNetControl btn_scaleh "System.Windows.Forms.Button" pos:[12,128] width:300 height:26
    dotNetControl btn_rot_hcw "System.Windows.Forms.Button" pos:[12,170] width:72 height:24
    dotNetControl btn_rot_hccw "System.Windows.Forms.Button" pos:[86,170] width:72 height:24
    dotNetControl btn_rot_vcw "System.Windows.Forms.Button" pos:[160,170] width:72 height:24
    dotNetControl btn_rot_vccw "System.Windows.Forms.Button" pos:[234,170] width:72 height:24

    -- 第一步
    dotNetControl hdr1 "System.Windows.Forms.Button" pos:[12,216] width:300 height:22
    dotNetControl btn_pivot "System.Windows.Forms.Button" pos:[12,242] width:300 height:24
    -- 排方向 + 排距离 + 可选单位：同一排；排距离右对齐到下方按钮右缘(x=312)
    dotNetControl lbl_axis "System.Windows.Forms.Label" pos:[10,282] width:42 height:18
    radioButtons rdo_axis labels:#("X 轴", "Y 轴") default:1 columns:2 pos:[54,283]
    dotNetControl lbl_gap "System.Windows.Forms.Label" pos:[162,282] width:42 height:18
    spinner spn_gap "" range:[0,1000000,100] type:#float value:100 pos:[204,282] width:52 height:18 tooltip:"摆成一排时模型之间的间距（按右侧单位换算到场景单位）"
    dropdownlist ddl_gunit "" items:#("m", "cm", "mm") selection:2 pos:[260,279] width:52
    dotNetControl btn_arrange "System.Windows.Forms.Button" pos:[12,308] width:300 height:24
    dotNetControl btn_xform "System.Windows.Forms.Button" pos:[12,348] width:300 height:24
    dotNetControl btn_fixnormal "System.Windows.Forms.Button" pos:[12,388] width:300 height:24

    -- 第二步
    dotNetControl hdr2 "System.Windows.Forms.Button" pos:[12,434] width:300 height:22
    dotNetControl btn_check_ngon "System.Windows.Forms.Button" pos:[12,546] width:300 height:24
    dotNetControl lbl_dup "System.Windows.Forms.Label" pos:[12,586] width:78 height:18
    spinner spn_dupdist "" range:[0,1000,0.1] type:#float value:0.1 pos:[92,586] width:74 tooltip:"两点距离小于此值算重复点（默认 0.1）"
    dropdownlist ddl_duptype "" items:#("所有距离相近的点", "可焊接的重复点") selection:2 pos:[168,584] width:144 tooltip:"所有距离相近的点：按阈值找全部顶点里距离相近的点（含内部重合点、靠得近的独立元素，最宽松）。\n可焊接的重复点：只找开放边界上、距离相近的点（= 可编辑多边形焊接真正能合并的、该缝合的松散点；内部重合点焊不动会自动排除，并已设好焊接阈值便于直接焊）。"
    dotNetControl btn_check_loose "System.Windows.Forms.Button" pos:[12,612] width:300 height:24
    dotNetControl lbl_sg "System.Windows.Forms.Label" pos:[12,460] width:182 height:18
    dotNetControl lbl_sgang "System.Windows.Forms.Label" pos:[198,460] width:34 height:18
    spinner spn_sgangle "" range:[0,180,45] type:#float value:45.0 pos:[234,460] width:56 tooltip:"‘角度分平滑组’用的角度阈值（默认 45°）"
    dotNetControl btn_smoothremind "System.Windows.Forms.Button" pos:[12,484] width:146 height:24
    dotNetControl btn_autosmooth "System.Windows.Forms.Button" pos:[166,484] width:146 height:24
    dotNetControl lbl_sgtip "System.Windows.Forms.Label" pos:[12,514] width:300 height:16

    -- 第三步
    dotNetControl hdr3 "System.Windows.Forms.Button" pos:[12,658] width:300 height:22
    dotNetControl btn_clean_clutter "System.Windows.Forms.Button" pos:[12,684] width:300 height:24
    dotNetControl chk_merge_0 "System.Windows.Forms.CheckBox" pos:[12,720] width:300 height:18
    dotNetControl btn_clean_layer "System.Windows.Forms.Button" pos:[12,742] width:300 height:24
    dotNetControl chk_keep_used "System.Windows.Forms.CheckBox" pos:[12,778] width:300 height:18
    dotNetControl btn_clean_mat "System.Windows.Forms.Button" pos:[12,800] width:300 height:24

    -- 第四步
    dotNetControl hdr4 "System.Windows.Forms.Button" pos:[12,846] width:300 height:22
    dotNetControl btn_browse "System.Windows.Forms.Button" pos:[12,872] width:300 height:24
    edittext edt_path "" pos:[12,908] width:300 readonly:true
    dotNetControl lbl_fmt "System.Windows.Forms.Label" pos:[12,939] width:44 height:16
    dropdownlist ddl_format "" items:#("FBX", "OBJ") pos:[54,936] width:66
    dotNetControl lbl_nm "System.Windows.Forms.Label" pos:[128,939] width:44 height:16
    dropdownlist ddl_naming "" items:#("用物体名", "前缀 + 物体名", "物体名 + 后缀", "名称 + 序号") pos:[170,936] width:142
    dotNetControl lbl_base_tip "System.Windows.Forms.Label" pos:[12,964] width:300 height:15
    edittext edt_base "" text:"exported" pos:[12,983] width:300
    dotNetControl chk_smooth "System.Windows.Forms.CheckBox" pos:[12,1009] width:300 height:18
    dotNetControl chk_zero "System.Windows.Forms.CheckBox" pos:[12,1029] width:300 height:18
    dotNetControl btn_export "System.Windows.Forms.Button" pos:[12,1051] width:300 height:28

    -- ========================================================
    --  功能函数
    -- ========================================================

    local gLastErr = ""   -- 记录最近一次检查的报错文字，便于排查
    local ttip = undefined   -- 悬停提示组件（在 open 时创建，需保持引用避免被回收）
    local gIconKeep = #()    -- 保留所有图标位图的引用，防止被 MAXScript GC 释放（否则按钮显示红叉/参数无效）
    -- 折叠模块：点击彩色标题条折叠/展开各模块，下方自动上移、面板自动缩短
    local secHdr = #()       -- 5 个标题控件
    local secBody = #()      -- 每个模块的所有控件 + 方框
    local secTitle = #()     -- 标题基础文字（不含 ▼/▶ 指示）
    local secHeight = #(188, 200, 206, 170, 237)   -- 各模块展开时的高度
    local secCollapsed = #(false, false, false, false, false)
    local origHdrY = #()     -- 标题原始 y
    local origBodyY = #()    -- 各模块内控件原始 y
    local secFont = undefined  -- 大标题字体（雅黑11加粗），重排时反复强制赋回，防止按钮回退默认字体

    -- ── 用 GDI+ 画 16×16 功能图标（透明底 + 黑色挖空，靠按钮黑底显形）──
    fn MakeIcon mode iconClr num =
    (
        local bmp = undefined
        try
        (
            local hasNum = (num != undefined and num != "")
            local w = if hasNum then 32 else 16
            bmp = dotNetObject "System.Drawing.Bitmap" w 16
            local g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
            local acCol = (dotNetClass "System.Drawing.Color").FromArgb 236 152 64
            local shCol = if iconClr != undefined then iconClr else ((dotNetClass "System.Drawing.Color").FromArgb 202 208 216)
            local ac = dotNetObject "System.Drawing.SolidBrush" acCol
            local sh = dotNetObject "System.Drawing.SolidBrush" shCol
            local bk = dotNetObject "System.Drawing.SolidBrush" ((dotNetClass "System.Drawing.Color").FromArgb 0 0 0)
            try ( g.SmoothingMode = (dotNetClass "System.Drawing.Drawing2D.SmoothingMode").AntiAlias ) catch ()
            g.TranslateTransform 0 -1   -- 序号 + 符号整体上移 1px（解决偏下）
            if hasNum do
            (
                -- 在左侧 16×16 框内「上下左右居中」画序号，再把后续图标整体右移 16px（序号 → 图标 → 文字）
                try (
                    g.TextRenderingHint = (dotNetClass "System.Drawing.Text.TextRenderingHint").AntiAliasGridFit
                    local fnt = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 9.0
                    local sf = dotNetObject "System.Drawing.StringFormat"
                    sf.Alignment = (dotNetClass "System.Drawing.StringAlignment").Center
                    sf.LineAlignment = (dotNetClass "System.Drawing.StringAlignment").Center
                    g.DrawString num fnt sh (dotNetObject "System.Drawing.RectangleF" 0.0 0.0 16.0 16.0) sf
                    append gIconKeep fnt   -- 保留字体引用，画完不释放，避免 GC 误伤
                ) catch ()
                g.TranslateTransform 16 0
            )
            case mode of
            (
                #import:  ( g.FillRectangle ac 7 1 2 7; g.FillRectangle ac 4 7 8 1; g.FillRectangle ac 5 8 6 1; g.FillRectangle ac 6 9 4 1; g.FillRectangle ac 7 10 2 1; g.FillRectangle sh 2 13 12 2 )
                #export:  ( g.FillRectangle ac 7 6 2 7; g.FillRectangle ac 7 2 2 1; g.FillRectangle ac 6 3 4 1; g.FillRectangle ac 5 4 6 1; g.FillRectangle ac 4 5 8 1; g.FillRectangle sh 2 13 12 2 )
                #height:  ( g.FillRectangle ac 7 1 2 12; g.FillRectangle ac 6 2 4 1; g.FillRectangle ac 5 3 6 1; g.FillRectangle ac 5 10 6 1; g.FillRectangle ac 6 11 4 1 )
                #scale:   ( g.FillRectangle ac 2 2 7 2; g.FillRectangle ac 2 2 2 7; g.FillRectangle ac 7 12 7 2; g.FillRectangle ac 12 7 2 7 )
                #rotcw:   ( local pn = dotNetObject "System.Drawing.Pen" acCol 2.0; g.DrawArc pn 2 2 11 11 0 270; pn.Dispose(); g.FillRectangle ac 7 0 2 5; g.FillRectangle ac 9 1 2 3; g.FillRectangle ac 11 2 1 1 )
                #rotccw:  ( local pn = dotNetObject "System.Drawing.Pen" acCol 2.0; g.DrawArc pn 2 2 11 11 180 -270; pn.Dispose(); g.FillRectangle ac 7 0 2 5; g.FillRectangle ac 5 1 2 3; g.FillRectangle ac 4 2 1 1 )
                #pivot:   ( g.FillRectangle ac 7 2 2 10; g.FillRectangle ac 3 6 10 2; g.FillRectangle sh 3 13 10 2 )
                #arrange: ( g.FillRectangle sh 1 5 4 6; g.FillRectangle sh 6 5 4 6; g.FillRectangle sh 11 5 4 6; g.FillRectangle ac 1 12 14 1 )
                #reset:   ( g.FillEllipse ac 2 2 12 12; g.FillEllipse bk 5 5 6 6; g.FillRectangle bk 10 0 6 7; g.FillRectangle ac 9 0 5 1; g.FillRectangle ac 13 0 1 5 )
                #normal:  ( g.FillRectangle sh 2 9 12 4; g.FillRectangle ac 7 2 2 7; g.FillRectangle ac 6 3 4 1; g.FillRectangle ac 5 4 6 1; g.FillRectangle ac 7 2 2 1 )
                #ngon:    ( g.FillRectangle sh 5 1 6 2; g.FillRectangle sh 3 3 10 2; g.FillRectangle sh 1 5 14 6; g.FillRectangle sh 3 11 10 2; g.FillRectangle sh 5 13 6 2; g.FillRectangle bk 5 5 6 6 )
                #dots:    ( g.FillEllipse sh 2 2 2 2; g.FillEllipse sh 11 3 2 2; g.FillEllipse sh 12 11 2 2; g.FillEllipse sh 3 12 2 2; g.FillEllipse ac 6 6 4 4 )
                #uv:      ( g.FillRectangle sh 2 2 5 5; g.FillRectangle sh 9 9 5 5; g.FillRectangle ac 9 2 5 5; g.FillRectangle ac 2 9 5 5 )
                #angle:   ( g.FillRectangle ac 2 2 2 12; g.FillRectangle ac 2 12 12 2; g.FillRectangle sh 5 8 5 1; g.FillRectangle sh 5 5 1 4 )
                #trash:   ( g.FillRectangle ac 2 2 12 2; g.FillRectangle ac 6 0 4 2; g.FillRectangle sh 3 4 10 11; g.FillRectangle bk 5 6 1 7; g.FillRectangle bk 8 6 1 7; g.FillRectangle bk 11 6 1 7 )
                #layers:  ( g.FillRectangle sh 3 7 10 3; g.FillRectangle sh 3 12 10 3; g.FillRectangle ac 3 2 10 1; g.FillRectangle ac 3 4 10 1; g.FillRectangle ac 3 2 1 3; g.FillRectangle ac 12 2 1 3 )
                #sphere:  ( g.FillEllipse sh 2 2 12 12; g.FillEllipse ac 4 4 3 3 )
                #folder:  ( g.FillRectangle ac 2 5 12 9; g.FillRectangle ac 2 3 6 2; g.FillRectangle bk 3 7 10 1 )
                default:  ()
            )
            g.Dispose()
        )
        catch ( bmp = undefined )
        bmp
    )


    -- ── 轴心归底（居中并贴地）──────────────────────────────
    fn PivotToBottom obj =
    (
        obj.pivot = [(obj.min.x+obj.max.x)/2.0, (obj.min.y+obj.max.y)/2.0, obj.min.z]
    )

    -- ── 等比缩放到指定高度（按 Z 轴包围盒高度）──────────────
    --  每个物体单独等比缩放，使自身高度 = targetH。返回是否成功。
    fn ScaleToHeight obj targetH =
    (
        local h = obj.max.z - obj.min.z
        if h > 1.0e-6 then
        (
            obj.scale *= (targetH / h)
            true
        )
        else false
    )

    -- ── 识别选中物体的高度（Z 轴包围盒高，系统单位）──────────
    fn GetSelZHeight objs =
    (
        if objs.count == 0 then 0.0
        else
        (
            local mn = objs[1].min.z ; local mx = objs[1].max.z
            for o in objs do ( if o.min.z < mn do mn = o.min.z ; if o.max.z > mx do mx = o.max.z )
            (mx - mn)
        )
    )

    -- ── 绕世界轴旋转 ang 度（绕各自轴心）──────────────────────
    fn RotateObjs objs ang ax =
    (
        for obj in objs do rotate obj (angleaxis ang ax)
    )

    -- ── 排列成一排 ─────────────────────────────────────────
    fn ArrangeObjects objs useX gap =
    (
        local cursor = 0.0
        for obj in objs do
        (
            local sx = obj.max.x - obj.min.x
            local sy = obj.max.y - obj.min.y
            if useX then
            (
                obj.pos.x += cursor - obj.min.x
                obj.pos.y  = 0
                cursor += sx + gap
            )
            else
            (
                obj.pos.y += cursor - obj.min.y
                obj.pos.x  = 0
                cursor += sy + gap
            )
            obj.pos.z = 0
        )
    )

    -- ── 重置变换 → 可编辑多边形 ─────────────────────────────
    fn DoResetXForm obj =
    (
        try
        (
            select obj
            ResetXForm obj          -- Max 内置：把旋转/缩放正确烘焙进网格，不复制节点
            collapseStack obj       -- 塌陷修改器堆栈
            convertTo obj Editable_Poly
            update obj
        )
        catch ( messageBox ("重置变换出错：" + obj.name + "\n" + getCurrentException()) title:"错误" )
    )

    -- ── 修复法线：逐面把"朝内"的面翻到朝外（可编辑多边形自带「翻转」）→ 解决发黑/看穿 ──
    --  关键认知（均在 Max 实测）：①「法线」修改器 unify 只统一不朝外、对单面翻转无效；
    --  ②真正能逐面翻转面朝向的是可编辑多边形对象的 #FlipNormals（即 UI 多边形层级的「翻转」按钮）；
    --  ③用"面法线·(面心−质心)"判断每个面朝内/朝外，逐面翻转朝内的面。
    --  返回值 = 翻转的面数（-1 表示出错）。
    --  注意：对实心模型可靠；极凹/空心带内表面的模型，内表面会被误判为朝内而翻掉（属几何判据固有局限）。
    fn FixNormals obj =
    (
        local flippedCount = -1
        try
        (
            convertToPoly obj

            -- ① 清除显式(已编辑/导入)法线 → 回到由几何+光滑组计算（解决"显式法线坏了导致发暗/发黑"）
            try
            (
                local en = Edit_Normals()
                addModifier obj en
                try ( max modify mode ) catch ()
                try ( modPanel.setCurrentObject en ) catch ()
                local nn = en.GetNumNormals()
                if nn > 0 do en.Reset selection:#{1..nn} node:obj
                convertToPoly obj
            )
            catch ( try ( convertToPoly obj ) catch () )

            -- ② 逐面检测朝内 → 选中 → 用可编辑多边形「翻转」翻到朝外
            try ( max modify mode ) catch ()
            try ( modPanel.setCurrentObject obj.baseobject ) catch ()
            try ( subobjectLevel = 4 ) catch ()
            flippedCount = 0
            local nf = polyop.getNumFaces obj
            if nf > 0 do
            (
                -- 质心（顶点抽样，兼顾大模型）
                local nv = polyop.getNumVerts obj
                local c = [0,0,0] ; local vcnt = 0 ; local vstep = amax 1 (nv / 800)
                local vi = 1
                while vi <= nv do ( c += polyop.getVert obj vi ; vcnt += 1 ; vi += vstep )
                if vcnt > 0 do c /= vcnt

                -- 逐面判断朝内（全检，不漏）
                local bad = #{}
                for f = 1 to nf do
                (
                    local dir = (polyop.getFaceCenter obj f) - c
                    if (length dir) > 1.0e-5 do ( if (dot (polyop.getFaceNormal obj f) dir) < 0 do bad[f] = true )
                )
                if bad.numberSet > 0 do
                (
                    polyop.setFaceSelection obj bad
                    local ok = false
                    try ( obj.EditablePoly.buttonOp #FlipNormals ; ok = true ) catch ()
                    if not ok do try ( obj.buttonOp #FlipNormals ) catch ()
                    flippedCount = bad.numberSet
                    update obj
                )
            )
            update obj
        )
        catch ( flippedCount = -1 )
        flippedCount
    )

    -- ── 按角度自动平滑组：用 Smooth 修改器的「自动平滑」，再塌陷烘焙 ──
    fn AutoSmoothObj obj angle =
    (
        try ( local sm = Smooth() ; sm.autosmooth = true ; sm.threshold = angle ; addModifier obj sm ; convertTo obj Editable_Poly ; update obj ; true )
        catch ( false )
    )

    -- ── 按 UV 拆分生成平滑组：每个 UV 块(岛)一个平滑组，UV 缝处=硬边，未拆处=软过渡。
    --  返回生成的平滑组(岛)数量；无 UV 返回 0；出错返回 -1。
    fn SmoothFromUV obj =
    (
        try
        (
            convertToPoly obj
            local ch = 1
            if not (polyop.getMapSupport obj ch) then return 0   -- 模型没有 UV

            local nf = polyop.getNumFaces obj
            local ne = polyop.getNumEdges obj

            -- 预存每个面的几何顶点 与 UV(map)顶点（同一角点顺序对齐）
            local fGeo = #() ; local fMap = #()
            for f = 1 to nf do ( fGeo[f] = polyop.getFaceVerts obj f ; fMap[f] = polyop.getMapFace obj ch f )

            -- 逐边判断是否 UV 缝：建立"非缝邻接"(用于划分 UV 岛) 与 "缝两侧面对"(用于岛着色)
            local adj = #()
            for f = 1 to nf do adj[f] = #()
            local seamPairs = #()
            for e = 1 to ne do
            (
                local ef = (polyop.getFacesUsingEdge obj e) as array
                if ef.count == 2 do
                (
                    local f1 = ef[1] ; local f2 = ef[2]
                    local ev = polyop.getEdgeVerts obj e
                    local v1 = ev[1] ; local v2 = ev[2]
                    local g1 = fGeo[f1] ; local m1 = fMap[f1]
                    local g2 = fGeo[f2] ; local m2 = fMap[f2]
                    local a1 = 0 ; local b1 = 0 ; local a2 = 0 ; local b2 = 0
                    for i = 1 to g1.count do ( if g1[i] == v1 then a1 = m1[i] else if g1[i] == v2 then b1 = m1[i] )
                    for i = 1 to g2.count do ( if g2[i] == v1 then a2 = m2[i] else if g2[i] == v2 then b2 = m2[i] )
                    if (a1 == a2 and b1 == b2) then
                    ( append adj[f1] f2 ; append adj[f2] f1 )       -- UV 连续 → 同岛(软边)
                    else
                    ( append seamPairs #(f1, f2) )                  -- UV 拆开 → 缝(硬边)
                )
            )

            -- 洪水填充 → 每个面归入一个 UV 岛
            local island = #()
            for f = 1 to nf do island[f] = 0
            local nIsland = 0
            for s = 1 to nf do
            (
                if island[s] == 0 do
                (
                    nIsland += 1
                    local stack = #(s)
                    island[s] = nIsland
                    while stack.count > 0 do
                    (
                        local cur = stack[stack.count] ; deleteItem stack stack.count
                        for nb in adj[cur] do ( if island[nb] == 0 do ( island[nb] = nIsland ; append stack nb ) )
                    )
                )
            )

            -- 岛邻接图（通过缝相邻的不同岛）
            local inbr = #()
            for i = 1 to nIsland do inbr[i] = #()
            for pr in seamPairs do
            (
                local ia = island[pr[1]] ; local ib = island[pr[2]]
                if ia != ib do ( appendIfUnique inbr[ia] ib ; appendIfUnique inbr[ib] ia )
            )

            -- 贪心着色：给每个岛分配 1..32 的平滑组，相邻岛(缝两侧)必不同 → 缝处=硬边
            local isg = #()
            for i = 1 to nIsland do isg[i] = 0
            for i = 1 to nIsland do
            (
                local used = #{}
                for nb in inbr[i] do ( if isg[nb] != 0 do used[isg[nb]] = true )
                local c = 1
                while c <= 32 and used[c] do c += 1
                if c > 32 do c = 1
                isg[i] = c
            )

            -- 应用：按平滑组把面分桶，统一设置
            local buckets = #()
            for i = 1 to 32 do buckets[i] = #{}
            for f = 1 to nf do buckets[isg[island[f]]][f] = true
            for sg = 1 to 32 do
                if buckets[sg].numberSet > 0 do
                    polyop.setFaceSmoothGroup obj buckets[sg] (bit.shift 1 (sg-1))

            update obj
            nIsland
        )
        catch ( -1 )
    )

    -- ── 批量导入 ─────────────────────────────────────────────
    fn ImportModels =
    (
        local dlg = dotNetObject "System.Windows.Forms.OpenFileDialog"
        dlg.Multiselect = true
        dlg.Title = "选择要导入的模型文件（可多选）"
        dlg.Filter = "常见模型(*.fbx;*.obj;*.3ds;*.dae;*.stl;*.dwg;*.dxf;*.3dm;*.ai;*.glb;*.gltf)|*.fbx;*.obj;*.3ds;*.dae;*.stl;*.dwg;*.dxf;*.3dm;*.ai;*.glb;*.gltf|所有文件(*.*)|*.*"
        if (dlg.ShowDialog()).ToString() == "OK" then
        (
            local ok = 0
            local fail = 0
            for f in dlg.FileNames do
            (
                try ( importFile f #noPrompt ; ok += 1 )
                catch ( fail += 1 )
            )
            local msg = "√ 导入完成\n   成功：" + ok as string + " 个"
            if fail > 0 then msg += "\n   失败：" + fail as string + " 个"
            messageBox msg title:"批量导入"
        )
    )

    -- ── 重复点排序扫描用的比较函数（按 x 排序）──────────────
    fn _cmpVertX a b = ( if a[2].x < b[2].x then -1 else if a[2].x > b[2].x then 1 else 0 )

    -- ── 检查废点/重复点（直接清理版）──────────────────────────
    --  转可编辑多边形 → 删孤立点(废点) + 移未用贴图顶点 → 找重复点并预选(进点层级即显示)。
    --  返回 #(删除的废点数, 重复点数)；出错返回 undefined。
    fn CleanVerts obj thr mode =
    (
        local res = undefined
        try
        (
            convertToPoly obj

            -- ① 删孤立点(废点)：先统计数量，再用内置方法删除
            local nv0 = polyop.getNumVerts obj
            local nf  = polyop.getNumFaces obj
            local usedV = #{}
            for f = 1 to nf do for vi in (polyop.getFaceVerts obj f) do usedV[vi] = true
            local isoCount = ((#{1..nv0}) - usedV).numberSet
            polyop.deleteIsoVerts obj

            -- ② 移除未使用的贴图顶点（EditablePoly 接口方法）
            try ( obj.DeleteIsoMapVerts() ) catch ()

            -- ③ 找重复/极近点（删点后重新取点），按 x 排序只比对邻近
            --  模式1「所有距离相近的点」= 全部顶点里找；
            --  模式2「可焊接的重复点」= 只在【开放边界点】里找——可编辑多边形焊接只焊得动
            --  开放边界上的松散点，内部重合点（如两闭合面贴合处）焊不动，故排除，精准对应手动焊接。
            local nv = polyop.getNumVerts obj
            local dup = #{}
            if thr > 0.0 and nv > 0 do
            (
                local cand = #{1..nv}
                if mode == 2 do
                (
                    local oe = polyop.getOpenEdges obj
                    cand = if oe.numberSet > 0 then (polyop.getVertsUsingEdge obj oe) else (#{})
                )
                local items = for v in (cand as array) collect #(v, (polyop.getVert obj v))
                qsort items _cmpVertX
                local thr2 = thr * thr
                local n = items.count
                for i = 1 to n do
                (
                    local pi = items[i][2]
                    local j  = i + 1
                    local stop = false
                    while (j <= n) and (not stop) do
                    (
                        local pj = items[j][2]
                        if ((pj.x - pi.x) > thr) then stop = true
                        else ( local d = pi - pj ; if (dot d d) <= thr2 do ( dup[items[i][1]] = true ; dup[items[j][1]] = true ) )
                        j += 1
                    )
                )
            )
            local dupCount = dup.numberSet
            if dupCount > 0 do
            (
                polyop.setVertSelection obj dup   -- 预选问题点
                if mode == 2 do ( try ( obj.weldThreshold = thr ) catch () )   -- 设焊接阈值，手动焊接按此距离即可合并
            )
            update obj
            res = #(isoCount, dupCount)
        )
        catch ( res = undefined ; gLastErr = (obj.name + "：" + getCurrentException()) )
        res
    )

    -- ── 检查并标记问题子物体 ────────────────────────────────
    --  做法：先复制一份并塌陷为可编辑多边形读取问题索引（polyop 稳定可靠，
    --  且完全不动原物体）；再给【原物体】单独加一个「编辑多边形」修改器，
    --  把问题面/点选中。这样每个物体各自独立、不塌陷、不合并。
    --  kind: #Face 多边面(>4边) ; #Vertex 废点(孤立)+重复点(距离<thr)
    --  返回选中数量；无问题返回 0；出错返回 -1。
    fn MarkIssue obj kind thr =
    (
        local cnt = -1
        local cp = undefined
        try
        (
            -- 1) 用副本读取问题索引（绝不修改原物体）
            cp = copy obj
            try ( convertToPoly cp ) catch ( convertTo cp Editable_Poly )
            local sel = #{}

            if kind == #Face then
            (
                local nf = polyop.getNumFaces cp
                for f = 1 to nf do
                    if (polyop.getFaceVerts cp f).count > 4 do sel[f] = true
            )
            else
            (
                local nv = polyop.getNumVerts cp
                local nf = polyop.getNumFaces cp
                -- ① 孤立点：没有被任何面使用的点（只用确定存在的 getFaceVerts）
                local usedVerts = #{}
                for f = 1 to nf do
                    for vi in (polyop.getFaceVerts cp f) do usedVerts[vi] = true
                for v = 1 to nv do
                    if (not usedVerts[v]) do sel[v] = true
                -- ② 重复/极近点：按 x 排序后只与 x 距离 < thr 的点比对（纯 MAXScript）
                if thr > 0.0 do
                (
                    local items = for v = 1 to nv collect #(v, (polyop.getVert cp v))
                    qsort items _cmpVertX
                    local thr2 = thr * thr
                    local n = items.count
                    for i = 1 to n do
                    (
                        local pi = items[i][2]
                        local j  = i + 1
                        local stop = false
                        while (j <= n) and (not stop) do
                        (
                            local pj = items[j][2]
                            if ((pj.x - pi.x) > thr) then
                                stop = true
                            else
                            (
                                local d = pi - pj
                                if (dot d d) <= thr2 do ( sel[items[i][1]] = true ; sel[items[j][1]] = true )
                            )
                            j += 1
                        )
                    )
                )
            )

            delete cp
            cp = undefined

            cnt = sel.numberSet
            if cnt > 0 then
            (
                -- 2) 给原物体单独加「编辑多边形」修改器并选中问题子物体
                select obj
                max modify mode
                local ep = Edit_Poly()
                addModifier obj ep
                modPanel.setCurrentObject ep
                local lvl = if kind == #Face then #Face else #Vertex
                ep.SetEPolySelLevel lvl
                ep.SetSelection lvl #{}
                ep.Select lvl sel
            )
        )
        catch
        (
            cnt = -1
            gLastErr = (obj.name + "：" + getCurrentException())
            if cp != undefined do ( try ( delete cp ) catch () )   -- 出错也删掉临时副本，避免场景里堆副本
        )
        return cnt
    )

    -- ── 清理空层级 ───────────────────────────────────────────
    fn CleanLayers delEmpty mergeTo0 =
    (
        try
        (
            local deleted = 0
            local merged  = 0
            local skipped = 0
            local lm      = LayerManager

            if mergeTo0 then
            (
                local layer0 = lm.getLayer 0
                local lc = lm.count
                for i = 1 to lc do
                (
                    local layer = lm.getLayer (i-1)
                    if layer != undefined and layer != layer0 then
                    (
                        local node_arr = #()
                        layer.nodes &node_arr
                        for obj in node_arr do ( layer0.addNode obj ; merged += 1 )
                    )
                )
            )

            local to_delete = #()
            local lc = lm.count
            for i = 1 to lc do
            (
                local layer = lm.getLayer (i-1)
                if layer == undefined then continue
                if layer.name == "0" then continue

                local node_arr = #()
                layer.nodes &node_arr
                if delEmpty and node_arr.count == 0 then
                    append to_delete layer.name
                else
                    skipped += 1
            )

            for layer_name in to_delete do
            (
                try ( lm.deleteLayerByName layer_name ; deleted += 1 ) catch()
            )

            local msg = "√ 层级清理完成\n   删除空层：" + deleted as string + " 个\n"
            if mergeTo0 then msg += "   归并物体：" + merged as string + " 个\n"
            msg += "   保留层：" + skipped as string + " 个"
            return msg
        )
        catch ( return ("× 层级清理出错：" + getCurrentException()) )
    )

    -- ── 清理材质球 ───────────────────────────────────────────
    fn CleanMaterialEditor keepUsed =
    (
        try
        (
            local cleaned = 0
            local kept    = 0

            local used_mats = #()
            if keepUsed then
                for obj in objects do
                    if obj.material != undefined then appendIfUnique used_mats obj.material

            for i = 1 to 24 do
            (
                local slot_mat = meditmaterials[i]
                if slot_mat != undefined then
                (
                    local is_used = false
                    if keepUsed then
                        for um in used_mats do ( if um == slot_mat then is_used = true )

                    if not is_used then
                    (
                        meditmaterials[i] = Standard()
                        meditmaterials[i].name = "Material_" + i as string
                        cleaned += 1
                    )
                    else kept += 1
                )
            )
            activeMeditSlot = activeMeditSlot

            local msg = "√ 材质清理完成\n   清除材质球：" + cleaned as string + " 个\n"
            if keepUsed then msg += "   保留使用中：" + kept as string + " 个"
            return msg
        )
        catch ( return ("× 清理出错：" + getCurrentException()) )
    )

    -- ── 删除杂物：只保留网格模型，删掉灯光/相机/骨骼/辅助物/曲线/空间扭曲等 ──
    fn DeleteNonModel =
    (
        local toDel = #()
        for obj in objects do
        (
            local keep = false
            if (superClassOf obj) == GeometryClass then
            (
                -- 几何体里把骨骼/Biped 当作杂物
                local c = classOf obj
                if (c == BoneGeometry) or (c == Biped_Object) then keep = false
                else keep = true
            )
            if not keep then append toDel obj
        )
        if toDel.count == 0 then ( messageBox "场景里没有需要清理的杂物，已全是模型。" title:"删除杂物" ; return() )
        if not (queryBox ("将删除 " + toDel.count as string + " 个非模型物体\n（灯光 / 相机 / 骨骼 / 辅助物 / 曲线 / 空间扭曲等），仅保留网格模型。\n\n确定删除吗？") title:"确认删除杂物") then return()
        local n = 0
        for o in toDel do ( try ( delete o ; n += 1 ) catch () )
        messageBox ("√ 已删除 " + n as string + " 个杂物，仅保留模型。") title:"删除杂物完成"
    )

    -- ── 批量导出（FBX / OBJ）──────────────────────────────────
    --  fmt: 1=FBX 2=OBJ ; namingMode: 1=物体名 2=前缀+物体名 3=名称+序号
    fn ExportModels path base objs fmt namingMode zeroCoords smoothGroups =
    (
        if path == "" then ( messageBox "请先选择导出文件夹！" title:"提示" ; return false )

        local ext = if fmt == 2 then ".obj" else ".fbx"

        -- FBX 导出选项（只对 FBX 生效，统一设置一次）
        --  仅保留平滑组：保留网格+平滑组+UV+法线，强制关掉动画/相机/灯光/蒙皮/Morph/内嵌贴图/切线等多余信息
        if ext == ".fbx" then
        (
            try ( FBXExporterSetParam "SmoothingGroups"    smoothGroups ) catch ()
            try ( FBXExporterSetParam "Animation"          false ) catch ()
            try ( FBXExporterSetParam "BakeAnimation"      false ) catch ()
            try ( FBXExporterSetParam "Cameras"            false ) catch ()
            try ( FBXExporterSetParam "Lights"             false ) catch ()
            try ( FBXExporterSetParam "Skin"               false ) catch ()
            try ( FBXExporterSetParam "Shape"              false ) catch ()
            try ( FBXExporterSetParam "EmbedTextures"      false ) catch ()
            try ( FBXExporterSetParam "TangentSpaceExport" false ) catch ()
            try ( FBXExporterSetParam "PointCache"         false ) catch ()
        )

        local backup_pos = #()
        for obj in objs do append backup_pos (copy obj.pos)
        if zeroCoords then for obj in objs do obj.pos = [0,0,0]

        local ok = true
        try
        (
            local idx = 0
            for obj in objs do
            (
                idx += 1
                select obj
                local nm = case namingMode of
                (
                    2: (base + obj.name)                                  -- 前缀 + 物体名
                    3: (obj.name + base)                                  -- 物体名 + 后缀
                    4: (base + "_" + (formattedPrint idx format:"03d"))   -- 名称 + 序号
                    default: obj.name                                     -- 用物体名
                )
                local out = path + "\\" + nm + ext
                if ext == ".fbx" then
                    exportFile out #noPrompt selectedOnly:true using:FBXEXP
                else
                    exportFile out #noPrompt selectedOnly:true
            )
        )
        catch
        (
            ok = false
            messageBox ("× 导出出错：\n" + getCurrentException()) title:"错误"
        )

        if zeroCoords then for i = 1 to objs.count do objs[i].pos = backup_pos[i]
        return ok
    )

    -- ========================================================
    --  参数记忆：把可调参数存到 plugcfg 下的 ini，重开自动恢复上次数值
    -- ========================================================
    fn TB_IniFile = ( (getDir #plugcfg) + "\\ModelToolboxSettings.ini" )

    fn LoadSettings =
    (
        local f = TB_IniFile()
        if not (doesFileExist f) do return false
        fn _g ff key def = ( local v = getINISetting ff "Settings" key ; if v == "" then def else v )
        try ( spn_height.value     = (_g f "height"  "1.0")  as float ) catch()
        try ( ddl_hunit.selection  = (_g f "hunit"   "2")    as integer ) catch()
        try ( rdo_axis.state       = (_g f "axis"    "1")    as integer ) catch()
        try ( spn_gap.value        = (_g f "gap"     "100")  as float ) catch()
        try ( ddl_gunit.selection  = (_g f "gunit"   "2")    as integer ) catch()
        try ( spn_dupdist.value    = (_g f "dupdist" "0.1")  as float ) catch()
        try ( ddl_duptype.selection = (_g f "duptype" "2")   as integer ) catch()
        try ( spn_sgangle.value    = (_g f "sgangle" "45.0") as float ) catch()
        try ( ddl_format.selection = (_g f "format"  "1")    as integer ) catch()
        try ( ddl_naming.selection = (_g f "naming"  "1")    as integer ) catch()
        try ( edt_base.text        = (_g f "base" "exported") ) catch()
        try ( chk_smooth.checked   = ((_g f "smooth"   "true")  == "true") ) catch()
        try ( chk_zero.checked     = ((_g f "zero"     "true")  == "true") ) catch()
        try ( chk_merge_0.checked  = ((_g f "merge0"   "false") == "true") ) catch()
        try ( chk_keep_used.checked = ((_g f "keepused" "true") == "true") ) catch()
        try ( edt_path.text        = (_g f "path" "") ) catch()
        try ( local cs = (_g f "collapse" "00000") ; for i = 1 to 5 do secCollapsed[i] = ((substring cs i 1) == "1") ) catch()
        true
    )

    fn SaveSettings =
    (
        local f = TB_IniFile()
        try ( setINISetting f "Settings" "height"   (spn_height.value as string) ) catch()
        try ( setINISetting f "Settings" "hunit"    (ddl_hunit.selection as string) ) catch()
        try ( setINISetting f "Settings" "axis"     (rdo_axis.state as string) ) catch()
        try ( setINISetting f "Settings" "gap"      (spn_gap.value as string) ) catch()
        try ( setINISetting f "Settings" "gunit"    (ddl_gunit.selection as string) ) catch()
        try ( setINISetting f "Settings" "dupdist"  (spn_dupdist.value as string) ) catch()
        try ( setINISetting f "Settings" "duptype"  (ddl_duptype.selection as string) ) catch()
        try ( setINISetting f "Settings" "sgangle"  (spn_sgangle.value as string) ) catch()
        try ( setINISetting f "Settings" "format"   (ddl_format.selection as string) ) catch()
        try ( setINISetting f "Settings" "naming"   (ddl_naming.selection as string) ) catch()
        try ( setINISetting f "Settings" "base"     (edt_base.text) ) catch()
        try ( setINISetting f "Settings" "smooth"   (if chk_smooth.checked then "true" else "false") ) catch()
        try ( setINISetting f "Settings" "zero"     (if chk_zero.checked then "true" else "false") ) catch()
        try ( setINISetting f "Settings" "merge0"   (if chk_merge_0.checked then "true" else "false") ) catch()
        try ( setINISetting f "Settings" "keepused" (if chk_keep_used.checked then "true" else "false") ) catch()
        try ( setINISetting f "Settings" "path"     (edt_path.text) ) catch()
        try ( local cs = "" ; for i = 1 to 5 do cs += (if secCollapsed[i] then "1" else "0") ; setINISetting f "Settings" "collapse" cs ) catch()
    )

    -- ── 折叠模块：重排布局（移动/隐藏控件 + 缩放面板）──────────
    -- 控件位置/可见性兼容辅助：dotNetControl 无 .pos（用 .Top/.Left），MAXScript 控件用 .pos —— 两者都覆盖
    fn _cY c = ( local r = undefined ; try ( r = c.pos.y ) catch () ; if r == undefined do try ( r = c.Top ) catch () ; if r == undefined do r = 0 ; r )
    fn _cMoveY c yy = ( local ok = false ; try ( c.pos = [c.pos.x, yy] ; ok = true ) catch () ; if not ok do try ( c.Top = yy ) catch () )
    fn _cVis c v = ( try ( c.visible = v ) catch () )

    fn MTB_relayout =
    (
        if secHdr.count != 5 or origHdrY.count != 5 do return false
        local y = origHdrY[1]
        for s = 1 to 5 do
        (
            local hdr = secHdr[s]
            local shift = y - origHdrY[s]
            _cMoveY hdr (origHdrY[s] + shift)
            try ( hdr.text = (if secCollapsed[s] then "▶  " else "▼  ") + secTitle[s] ) catch ()
            try ( if secFont != undefined do hdr.font = secFont ) catch ()   -- 强制恢复大标题字体（雅黑11加粗），防回退默认
            if secCollapsed[s] then
            (
                for c in secBody[s] do ( _cVis c false ; _cMoveY c 3000 )   -- 隐藏并移出可视区，避免残留控件挡住其它标题点击
                y += 24
            )
            else
            (
                local oy = origBodyY[s]
                for i = 1 to secBody[s].count do ( local c = secBody[s][i] ; _cMoveY c (oy[i] + shift) ; _cVis c true )
                y += secHeight[s]
            )
            y += 18
        )
        for h in secHdr do try ( h.BringToFront() ) catch ()   -- 标题条置顶，确保始终可点
        try ( ModelToolbox.height = (y - 18 + 12) ) catch ()
        true
    )

    fn MTB_toggle idx =
    (
        secCollapsed[idx] = not secCollapsed[idx]
        MTB_relayout()
        try ( SaveSettings() ) catch ()
    )

    fn _onHdr1 s a = MTB_toggle 1
    fn _onHdr2 s a = MTB_toggle 2
    fn _onHdr3 s a = MTB_toggle 3
    fn _onHdr4 s a = MTB_toggle 4
    fn _onHdr5 s a = MTB_toggle 5

    -- ========================================================
    --  事件
    -- ========================================================

    -- 按钮统一中性灰；模块用彩色粗体标题条区分
    on ModelToolbox open do
    (
        local flatF    = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
        local clrText  = (dotNetClass "System.Drawing.Color").White
        local fntUI    = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 9
        local fntHdr   = dotNetObject "System.Drawing.Font" "Microsoft YaHei" 11 ((dotNetClass "System.Drawing.FontStyle").Bold)
        -- 保留字体引用，防止被 GC 释放后控件重绘报「参数无效」(MeasureString)
        append gIconKeep fntUI
        append gIconKeep fntHdr
        try ( dotNet.setLifetimeControl fntUI #dotnet ) catch ()
        try ( dotNet.setLifetimeControl fntHdr #dotnet ) catch ()
        secFont = fntHdr   -- 供 MTB_relayout 反复强制赋回大标题字体
        local midAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        local cBtn     = ((dotNetClass "System.Drawing.Color").FromArgb 0 0 0)       -- 按钮纯黑底
        local cBtnTxt  = ((dotNetClass "System.Drawing.Color").FromArgb 202 208 216) -- 按钮浅灰字（介于纯白与蓝灰之间）
        local clrLbl   = ((dotNetClass "System.Drawing.Color").FromArgb 150 168 195) -- 标注/勾选 蓝灰字
        local clrBg    = ((dotNetClass "System.Drawing.Color").FromArgb 56 56 56)    -- 面板底色（兜底）
        try
        (
            local bg = colorMan.getColor #background
            clrBg = (dotNetClass "System.Drawing.Color").FromArgb ((bg.x*255.0) as integer) ((bg.y*255.0) as integer) ((bg.z*255.0) as integer)
        )
        catch ()

        fn _mkClr r g b = ((dotNetClass "System.Drawing.Color").FromArgb r g b)

        -- 默认深底灰字；鼠标悬停略亮、按下时明显变亮（点击反馈）
        fn _styleBtn b txt col flatF clrText fntUI =
        (
            try ( b.text = txt ) catch ()
            try
            (
                b.flatStyle = flatF
                b.useVisualStyleBackColor = false
                b.backColor = col
                b.foreColor = clrText
                b.font      = fntUI
                b.flatAppearance.borderSize  = 1
                b.flatAppearance.borderColor = ((dotNetClass "System.Drawing.Color").FromArgb 90 90 90)
                b.flatAppearance.MouseOverBackColor = ((dotNetClass "System.Drawing.Color").FromArgb 88 88 88)
                b.flatAppearance.MouseDownBackColor = ((dotNetClass "System.Drawing.Color").FromArgb 122 122 122)
            )
            catch ()
        )

        fn _styleHdr h txt col clrText fntHdr midAlign =
        (
            try ( h.text = txt ) catch ()
            try
            (
                h.backColor = col
                h.foreColor = clrText
                h.font      = fntHdr
                h.textAlign = midAlign
            )
            catch ()
            -- 标题条是 Button（为了稳定接收点击）：扁平化、去边框、悬停/按下不变色，做成纯色条外观
            try
            (
                h.flatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                h.useVisualStyleBackColor = false
                h.flatAppearance.borderSize = 0
                h.flatAppearance.MouseOverBackColor = col
                h.flatAppearance.MouseDownBackColor = col
            )
            catch ()
        )

        -- 标注小字：蓝灰字 + 面板底色（不要白底）、左对齐
        fn _styleLbl L txt foreCol bgCol fnt =
        (
            try ( L.text = txt ) catch ()
            try
            (
                L.backColor = bgCol
                L.foreColor = foreCol
                L.font      = fnt
                L.textAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleLeft
            )
            catch ()
        )

        -- 勾选框：蓝灰字 + 面板底色
        fn _styleChk c txt isOn foreCol bgCol fnt =
        (
            try ( c.text = txt ) catch ()
            try
            (
                c.flatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Standard
                c.backColor = bgCol
                c.foreColor = foreCol
                c.font      = fnt
                c.checked   = isOn
            )
            catch ()
        )

        -- 彩色粗体标题条（低饱和、克制）
        _styleHdr hdr_aux   "辅助工具（导入 / 缩放 / 90°旋转）"  (_mkClr 84 134 154)  clrText fntHdr midAlign
        _styleHdr hdr1      "第一步 · 批量处理模型规范"       (_mkClr 86 122 170)  clrText fntHdr midAlign
        _styleHdr hdr2      "第二步 · 批量检查模型问题"       (_mkClr 90 144 108)  clrText fntHdr midAlign
        _styleHdr hdr3      "第三步 · 清理场景"               (_mkClr 174 142 90)  clrText fntHdr midAlign
        _styleHdr hdr4      "第四步 · 批量导出"               (_mkClr 142 112 168) clrText fntHdr midAlign

        _styleBtn btn_import      "批量导入模型文件（可多选）"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_getheight   "识别高度"                       cBtn flatF cBtnTxt fntUI
        _styleBtn btn_scaleh      "等比缩放到指定高度"           cBtn flatF cBtnTxt fntUI
        _styleBtn btn_rot_hcw     "水平-90°"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_rot_hccw    "水平+90°"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_rot_vcw     "竖直-90°"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_rot_vccw    "竖直+90°"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_pivot       "① 轴心置于中心底部"             cBtn flatF cBtnTxt fntUI
        _styleBtn btn_arrange     "② 摆成一排"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_xform       "③ 重置变换（并转可编辑多边形）" cBtn flatF cBtnTxt fntUI
        _styleBtn btn_fixnormal   "④ 修复法线（统一朝向并恢复显示）" cBtn flatF cBtnTxt fntUI
        _styleBtn btn_check_ngon     "② 检查多边面（自动选中 >4 边面的模型）" cBtn flatF cBtnTxt fntUI
        _styleBtn btn_check_loose    "③ 检查废点/重复点（自动选中问题点的模型）" cBtn flatF cBtnTxt fntUI
        _styleBtn btn_smoothremind   "① UV 壳分平滑组"   cBtn flatF cBtnTxt fntUI
        _styleBtn btn_autosmooth     "① 角度分平滑组"     cBtn flatF cBtnTxt fntUI
        _styleBtn btn_clean_clutter "① 删除杂物（灯光/相机/骨骼/辅助等）" cBtn flatF cBtnTxt fntUI
        _styleBtn btn_clean_layer "② 删除空层级"                     cBtn flatF cBtnTxt fntUI
        _styleBtn btn_clean_mat   "③ 清理多余材质球"                 cBtn flatF cBtnTxt fntUI
        _styleBtn btn_browse      "选择模型文件导出目录"          cBtn flatF cBtnTxt fntUI
        _styleBtn btn_export      "开始批量导出（每个物体一个文件）" cBtn flatF cBtnTxt fntUI

        -- 给按钮加功能图标（图标在文字左侧，看图识功能）
        fn _setIcon b mode iconClr =
        (
            try (
                local t = b.text
                local num = ""
                for n in #("①","②","③","④","⑤") do ( if (findString t n) == 1 do num = n )
                local ic = MakeIcon mode iconClr num
                if ic != undefined do
                (
                    append gIconKeep ic   -- 保留引用，防止位图被 GC 释放
                    try ( dotNet.setLifetimeControl ic #dotnet ) catch ()
                    if num != "" do b.text = trimLeft (substring t 2 -1)   -- 序号已画进图标，从文字去掉
                    b.Image = ic
                    b.ImageAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    b.TextAlign  = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    b.TextImageRelation = (dotNetClass "System.Windows.Forms.TextImageRelation").ImageBeforeText
                    -- 「图标+文字」整组默认左对齐（偏左量随文字长度变化）；按实测文字宽算左内边距，把整组精确推到水平正中。
                    -- 用 TextRenderer.MeasureText（GDI，与按钮实际文字渲染一致），比 GDI+ MeasureString 更准。
                    try (
                        local imgW = if num != "" then 32 else 16
                        local tsz = (dotNetClass "System.Windows.Forms.TextRenderer").MeasureText b.text b.Font
                        -- 经验系数：无边距偏左、(宽差)/2 偏右，取中点 /4 最接近正中（如仍偏，调这个分母）
                        local pad = ((b.Width - imgW - tsz.Width) / 4.0)
                        if pad < 0.0 do pad = 0.0
                        b.Padding = dotNetObject "System.Windows.Forms.Padding" (pad as integer) 0 0 0
                    ) catch ()
                )
            ) catch ()
        )
        _setIcon btn_import       #import   cBtnTxt
        _setIcon btn_getheight    #height   cBtnTxt
        _setIcon btn_scaleh       #scale    cBtnTxt
        _setIcon btn_pivot        #pivot    cBtnTxt
        _setIcon btn_arrange      #arrange  cBtnTxt
        _setIcon btn_xform        #reset    cBtnTxt
        _setIcon btn_fixnormal    #normal   cBtnTxt
        _setIcon btn_check_ngon   #ngon     cBtnTxt
        _setIcon btn_check_loose  #dots     cBtnTxt
        _setIcon btn_smoothremind #uv       cBtnTxt
        _setIcon btn_autosmooth   #angle    cBtnTxt
        _setIcon btn_clean_clutter #trash   cBtnTxt
        _setIcon btn_clean_layer  #layers   cBtnTxt
        _setIcon btn_clean_mat    #sphere   cBtnTxt
        _setIcon btn_browse       #folder   cBtnTxt
        _setIcon btn_export       #export   cBtnTxt

        -- 标注小字（灰色字 + 面板底色）
        _styleLbl lbl_import_tip "支持 FBX / OBJ / 3DS / DAE / STL / DWG 等格式" clrLbl clrBg fntUI
        _styleLbl lbl_th         "目标高度："              clrLbl clrBg fntUI
        _styleLbl lbl_axis       "排方向"                  clrLbl clrBg fntUI
        _styleLbl lbl_gap        "排距离"                  clrLbl clrBg fntUI
        _styleLbl lbl_dup        "重复点阈值："            clrLbl clrBg fntUI
        _styleLbl lbl_sg         "平滑组（二选一）："      clrLbl clrBg fntUI
        _styleLbl lbl_sgang      "角度"                    clrLbl clrBg fntUI
        _styleLbl lbl_sgtip      "※ 自动分平滑组后建议进「多边形」层级手动微调" clrLbl clrBg fntUI
        _styleLbl lbl_fmt        "格式："                  clrLbl clrBg fntUI
        _styleLbl lbl_nm         "命名："                  clrLbl clrBg fntUI
        _styleLbl lbl_base_tip   "用作前缀 / 名称；选「用物体名」时此项忽略" clrLbl clrBg fntUI

        -- 勾选框（蓝灰，最弱）
        _styleChk chk_merge_0  "清理前先把物体归并到 0 层"  false clrLbl clrBg fntUI
        _styleChk chk_keep_used "保留场景中正在使用的材质"  true  clrLbl clrBg fntUI
        _styleChk chk_smooth   "仅保留平滑组（导出纯几何体）" true  clrLbl clrBg fntUI
        _styleChk chk_zero     "导出前坐标归零"             true  clrLbl clrBg fntUI

        -- 分组描边：给 4 条边线统一上色（柔和偏蓝灰，和白色文字区分开、又不突兀）
        for p in #(g1t,g1b,g1l,g1r, g2t,g2b,g2l,g2r, g3t,g3b,g3l,g3r, g4t,g4b,g4l,g4r, g5t,g5b,g5l,g5r, g6t,g6b,g6l,g6r, g7t,g7b,g7l,g7r, \
                   g8t,g8b,g8l,g8r, g9t,g9b,g9l,g9r, g10t,g10b,g10l,g10r, g11t,g11b,g11l,g11r, g12t,g12b,g12l,g12r, g13t,g13b,g13l,g13r, g14t,g14b,g14l,g14r, g15t,g15b,g15l,g15r) do
        (
            try ( p.BackColor = (_mkClr 122 142 178) ) catch ()
        )

        -- 悬停提示：鼠标停在按钮上显示功能说明与用法
        try
        (
            ttip = dotNetObject "System.Windows.Forms.ToolTip"
            ttip.InitialDelay = 350
            ttip.AutoPopDelay = 15000
            ttip.ReshowDelay  = 200
            ttip.ShowAlways   = true
            ttip.SetToolTip btn_import      "一次选多个模型文件批量导入到场景。支持 FBX/OBJ/3DS/DAE/STL/DWG 等（glb/gltf 需 Max 2023+ 或装插件）。"
            ttip.SetToolTip btn_getheight   "量出选中模型的当前高度，按所选单位填入左侧‘目标高度’框，方便据此调整缩放比例。"
            ttip.SetToolTip btn_scaleh      "把选中的每个模型按‘目标高度’等比缩放（按 Z 轴高度）。用于把一批大小不一的模型统一高度。先选好模型。"
            ttip.SetToolTip btn_rot_hcw     "选中模型绕竖直轴(Z)顺时针旋转 90°（俯视方向旋转）。"
            ttip.SetToolTip btn_rot_hccw    "选中模型绕竖直轴(Z)逆时针旋转 90°。"
            ttip.SetToolTip btn_rot_vcw     "选中模型绕水平轴(X)顺时针旋转 90°（立起 / 放倒）。"
            ttip.SetToolTip btn_rot_vccw    "选中模型绕水平轴(X)逆时针旋转 90°。"
            ttip.SetToolTip btn_pivot       "把选中模型的轴心放到各自包围盒中心的最底部，方便贴地、对齐。"
            ttip.SetToolTip btn_arrange     "把选中的多个模型沿上方所选方向(X/Y)、按‘排列距离’依次排开，避免互相重叠。"
            ttip.SetToolTip btn_xform       "重置变换：清掉隐藏的旋转/缩放（缩放归 100%、轴对齐世界）并转可编辑多边形，解决负缩放、尺寸带系数、加修改器异常等。"
            ttip.SetToolTip btn_fixnormal   "把所有面法线统一朝外，修复‘面反了/发黑/看穿内部’。建议先点③重置变换、再修法线。"
            ttip.SetToolTip btn_check_ngon  "找出大于 4 边的面(N-Gon)，自动加编辑多边形并进入面层级选中、高亮，方便定位修改。先选模型。"
            ttip.SetToolTip btn_check_loose "调整上方重复点阈值，检测废点和重复点，自动删除废点。进入点层级自动选中重复点，方便焊接或删除。"
            ttip.SetToolTip btn_smoothremind "按 UV 拆分生成平滑组：每个 UV 壳一组，UV 缝=硬边、未拆=软过渡。适合 UV 已拆好的模型，不看角度。"
            ttip.SetToolTip btn_autosmooth  "按上方‘角度’阈值生成平滑组：相邻面夹角大于阈值=硬边、小于=软边。"
            ttip.SetToolTip btn_clean_clutter "只保留网格模型，删除场景里的灯光/相机/骨骼/辅助物/曲线/空间扭曲等。作用于整个场景，删前有确认弹窗。"
            ttip.SetToolTip btn_clean_layer "删除层管理器里没有物体的空层；可勾上方‘先归并到 0 层’再清理。"
            ttip.SetToolTip btn_clean_mat   "清掉材质编辑器里没用到的材质球；可勾上方‘保留场景中正在使用的材质’。"
            ttip.SetToolTip btn_browse      "选择批量导出的输出文件夹，路径会显示在下方文本框。"
            ttip.SetToolTip btn_export      "按上面设置把选中的每个模型各导出成一个文件。可勾‘仅保留平滑组’导纯几何体、‘坐标归零’让文件以原点为中心。"
        )
        catch ()

        -- 读取上次保存的参数（覆盖上面的默认值）
        try ( LoadSettings() ) catch ()

        -- ===== 折叠模块初始化：彩色标题条可点击折叠/展开 =====
        secHdr = #(hdr_aux, hdr1, hdr2, hdr3, hdr4)
        secTitle = #("辅助工具（导入 / 缩放 / 90°旋转）", "第一步 · 批量处理模型规范", "第二步 · 批量检查模型问题", "第三步 · 清理场景", "第四步 · 批量导出")
        secBody = #(
            #(lbl_import_tip, btn_import, lbl_th, spn_height, ddl_hunit, btn_getheight, btn_scaleh, btn_rot_hcw, btn_rot_hccw, btn_rot_vcw, btn_rot_vccw, g8t,g8b,g8l,g8r, g1t,g1b,g1l,g1r, g9t,g9b,g9l,g9r),
            #(btn_pivot, lbl_axis, rdo_axis, lbl_gap, spn_gap, ddl_gunit, btn_arrange, btn_xform, btn_fixnormal, g10t,g10b,g10l,g10r, g2t,g2b,g2l,g2r, g11t,g11b,g11l,g11r, g12t,g12b,g12l,g12r),
            #(btn_check_ngon, lbl_dup, spn_dupdist, ddl_duptype, btn_check_loose, lbl_sg, lbl_sgang, spn_sgangle, btn_smoothremind, btn_autosmooth, lbl_sgtip, g13t,g13b,g13l,g13r, g3t,g3b,g3l,g3r, g4t,g4b,g4l,g4r),
            #(btn_clean_clutter, chk_merge_0, btn_clean_layer, chk_keep_used, btn_clean_mat, g14t,g14b,g14l,g14r, g6t,g6b,g6l,g6r, g7t,g7b,g7l,g7r),
            #(btn_browse, edt_path, lbl_fmt, ddl_format, lbl_nm, ddl_naming, lbl_base_tip, edt_base, chk_smooth, chk_zero, btn_export, g15t,g15b,g15l,g15r, g5t,g5b,g5l,g5r)
        )
        try ( origHdrY = for h in secHdr collect (_cY h) ) catch ()
        try ( origBodyY = for bd in secBody collect (for c in bd collect (_cY c)) ) catch ()
        try (
            local hcur = (dotNetClass "System.Windows.Forms.Cursors").Hand
            for h in secHdr do try ( h.Cursor = hcur ) catch ()
        ) catch ()
        MTB_relayout()
    )

    -- 关闭面板时保存当前各项参数，下次打开自动恢复
    on ModelToolbox close do ( try ( SaveSettings() ) catch () )

    -- 点击彩色标题条折叠/展开对应模块（用 MouseDown：按下即触发，比 Click 灵敏可靠）
    on hdr_aux mouseDown do MTB_toggle 1
    on hdr1 mouseDown do MTB_toggle 2
    on hdr2 mouseDown do MTB_toggle 3
    on hdr3 mouseDown do MTB_toggle 4
    on hdr4 mouseDown do MTB_toggle 5

    on btn_import click do ImportModels()

    on btn_getheight click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local hSys = GetSelZHeight objs
        if hSys <= 0.0 then ( messageBox "选中物体高度为 0，无法识别。" title:"提示" ; return() )
        -- 按当前所选单位把系统单位高度换算后填入目标高度
        local unitStr = case ddl_hunit.selection of ( 1: "m" ; 2: "cm" ; 3: "mm" ; default: "m" )
        local perUnit = units.decodeValue ("1" + unitStr)   -- 1 个该单位 = 多少系统单位
        if perUnit == undefined or perUnit <= 0.0 do perUnit = 1.0
        spn_height.value = hSys / perUnit
        messageBox ("当前高度约 " + (formattedPrint (hSys / perUnit) format:".4g") + " " + unitStr + "，已填入目标高度。") title:"识别高度"
    )

    on btn_rot_hcw  click do ( local objs = getCurrentSelection() ; if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ) else ( undo "水平顺时针90" on RotateObjs objs -90.0 [0,0,1] ) )
    on btn_rot_hccw click do ( local objs = getCurrentSelection() ; if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ) else ( undo "水平逆时针90" on RotateObjs objs  90.0 [0,0,1] ) )
    on btn_rot_vcw  click do ( local objs = getCurrentSelection() ; if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ) else ( undo "垂直顺时针90" on RotateObjs objs -90.0 [1,0,0] ) )
    on btn_rot_vccw click do ( local objs = getCurrentSelection() ; if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ) else ( undo "垂直逆时针90" on RotateObjs objs  90.0 [1,0,0] ) )

    on btn_scaleh click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local raw = spn_height.value
        if raw <= 0.0 then ( messageBox "请输入大于 0 的目标高度！" title:"提示" ; return() )
        -- 把所选单位的高度换算成场景系统单位
        local unitStr = case ddl_hunit.selection of ( 1: "m" ; 2: "cm" ; 3: "mm" ; default: "m" )
        local th = units.decodeValue (raw as string + unitStr)
        if th == undefined or th <= 0.0 then ( messageBox "高度换算失败，请检查输入。" title:"提示" ; return() )
        local done = 0
        local skip = 0
        undo "等比缩放到指定高度" on
        (
            for obj in objs do
            (
                if (ScaleToHeight obj th) then done += 1 else skip += 1
            )
        )
        select objs
        local msg = "√ 已把 " + done as string + " 个物体等比缩放到 " + raw as string + " " + unitStr + " 高"
        if skip > 0 then msg += "\n（" + skip as string + " 个高度为 0 已跳过）"
        messageBox msg title:"完成"
    )

    on btn_smoothremind click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local done = 0
        local nouv = 0
        local fail = 0
        local totalIslands = 0
        undo "按UV拆分生成平滑组" on
        (
            for obj in objs do
            (
                local r = SmoothFromUV obj
                if r == -1 then fail += 1
                else if r == 0 then nouv += 1
                else ( done += 1 ; totalIslands += r )
            )
        )
        select objs
        local msg = "√ 已按 UV 拆分生成平滑组，共 " + done as string + " 个物体，" + totalIslands as string + " 个 UV 块\n"
        msg += "（UV 缝处 = 硬边，未拆处 = 软过渡）"
        if nouv > 0 then msg += "\n※ " + nouv as string + " 个物体没有 UV，已跳过"
        if fail > 0 then msg += "\n※ " + fail as string + " 个物体处理失败"
        messageBox msg title:"按 UV 生成平滑组完成"
    )

    on btn_autosmooth click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local ang = spn_sgangle.value
        local done = 0
        local fail = 0
        undo "按角度生成平滑组" on
        (
            for obj in objs do ( if (AutoSmoothObj obj ang) then done += 1 else fail += 1 )
        )
        select objs
        local msg = "√ 已按 " + ang as string + "° 自动生成平滑组，共 " + done as string + " 个物体"
        if fail > 0 then msg += "\n（" + fail as string + " 个处理失败）"
        messageBox msg title:"按角度生成平滑组完成"
    )

    on btn_pivot click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        undo "轴心居中贴地" on for obj in objs do PivotToBottom obj
        messageBox ("√ 已处理 " + objs.count as string + " 个物体") title:"完成"
    )

    on btn_arrange click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        -- 按所选单位把排列距离换算成场景系统单位
        local gUnit = case ddl_gunit.selection of ( 1: "m" ; 2: "cm" ; 3: "mm" ; default: "cm" )
        local gapSys = units.decodeValue (spn_gap.value as string + gUnit)
        if gapSys == undefined do gapSys = spn_gap.value
        undo "排成一排" on ArrangeObjects objs (rdo_axis.state==1) gapSys
        messageBox ("√ 已排列 " + objs.count as string + " 个物体（间距 " + spn_gap.value as string + " " + gUnit + "）") title:"完成"
    )

    on btn_xform click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        undo "重置变换" on for obj in objs do DoResetXForm obj
        select objs   -- 还原原始选择，避免只剩最后一个被选中
        messageBox ("√ 重置变换并转可编辑多边形完成，共 " + objs.count as string + " 个物体") title:"完成"
    )

    on btn_fixnormal click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local totalFlip = 0
        local errd = 0
        undo "修复法线" on
        (
            for obj in objs do
            (
                local r = FixNormals obj
                if r == -1 then errd += 1 else totalFlip += r
            )
        )
        try ( subobjectLevel = 0 ) catch ()   -- 退回物体层级
        select objs   -- 还原原始选择，避免只剩最后一个被选中
        (dotNetClass "System.Windows.Forms.MessageBox").Show ("√ 修复法线完成，共处理 " + objs.count as string + " 个物体\n√ 翻转朝内的面 " + totalFlip as string + " 个" + (if totalFlip == 0 then "\n（未发现朝内的面）" else "") + (if errd > 0 then "\n※ " + errd as string + " 个物体处理出错" else "")) "修复法线"
    )

    on btn_check_ngon click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local bad = #()
        local total = 0
        local errd = 0
        gLastErr = ""
        for obj in objs do
        (
            local c = MarkIssue obj #Face 0.0
            if c == -1 then errd += 1 else if c > 0 then ( append bad obj ; total += c )
        )
        if errd > 0 do messageBox ("有 " + errd as string + " 个物体检查出错，最后一条原因：\n\n" + gLastErr) title:"检查出错"
        if bad.count == 0 then
        (
            messageBox ("√ 没有发现多边面（>4 边）" + (if errd > 0 then "，但有 " + errd as string + " 个出错" else "")) title:"检查多边面"
        )
        else
        (
            select bad
            max modify mode
            subobjectLevel = 4   -- 4 = 多边形子层级（不锁定单个物体，保持多物体子层级编辑）
            redrawViews()
            messageBox ("× 多边面 " + total as string + " 个，分布在 " + bad.count as string + " 个模型，已选中并进入面层级") title:"检查多边面"
        )
    )

    on btn_check_loose click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local bad = #()        -- 含重复点的问题模型
        local totalDup = 0     -- 重复点总数
        local totalIso = 0     -- 已删除的废点总数
        local errd = 0
        local thr = spn_dupdist.value
        local mode = ddl_duptype.selection   -- 1=重合点(距离)  2=可焊接点(焊接会减少)
        gLastErr = ""
        undo "检查废点 / 重复点" on
        (
            for obj in objs do
            (
                local r = CleanVerts obj thr mode
                if r == undefined then errd += 1
                else ( totalIso += r[1] ; if r[2] > 0 do ( append bad obj ; totalDup += r[2] ) )
            )
        )
        if errd > 0 do messageBox ("有 " + errd as string + " 个物体处理出错，最后一条原因：\n\n" + gLastErr) title:"出错"
        if bad.count == 0 then
        (
            local okLine = if mode == 2 then "√ 未发现可焊接的重复点（开放边界上无距离相近的点）" else "√ 未发现距离相近的点"
            (dotNetClass "System.Windows.Forms.MessageBox").Show ("√ 已删除废点 " + totalIso as string + " 个\n√ 已清理未用贴图顶点\n" + okLine + (if errd > 0 then "\n※ " + errd as string + " 个物体处理出错" else "")) "检查废点 / 重复点"
        )
        else
        (
            select bad
            max modify mode
            subobjectLevel = 1   -- 1 = 顶点子层级（多物体保持子层级编辑）
            redrawViews()
            local hitLine = if mode == 2 then ("× 发现可焊接的重复点 " + totalDup as string + " 个（开放边界），分布在 " + bad.count as string + " 个模型") else ("× 发现距离相近的点 " + totalDup as string + " 个，分布在 " + bad.count as string + " 个模型")
            (dotNetClass "System.Windows.Forms.MessageBox").Show ("√ 已删除废点 " + totalIso as string + " 个\n√ 已清理未用贴图顶点\n" + hitLine + "\n已选中并进入点层级，问题点已预选\n可直接焊接 / 删除") "检查废点 / 重复点"
        )
    )

    on btn_clean_layer click do
    (
        local result = CleanLayers true chk_merge_0.checked
        messageBox result title:"层级清理结果"
    )

    on btn_clean_mat click do
    (
        local result = CleanMaterialEditor chk_keep_used.checked
        messageBox result title:"材质清理结果"
    )

    on btn_clean_clutter click do DeleteNonModel()

    on btn_browse click do
    (
        local dir = getSavePath caption:"选择导出文件夹"
        if dir != undefined then edt_path.text = dir
    )

    on btn_export click do
    (
        local objs = getCurrentSelection()
        if objs.count == 0 then ( messageBox "请先选择物体！" title:"提示" ; return() )
        local ok = ExportModels edt_path.text edt_base.text objs ddl_format.selection ddl_naming.selection \
                                 chk_zero.checked chk_smooth.checked
        if ok then messageBox "√ 导出完成！" title:"完成"
    )
)

createDialog ModelToolbox

    )
)
