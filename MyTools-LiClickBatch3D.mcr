macroScript LiClickBatch3D
category:"AAA我的工具 (MyTools)"
buttonText:"批量3d"
toolTip:"AI 批量图生3D：选图片文件夹 -> 自动上传 -> AI 生成 3D 模型 -> 自动导入场景（需 3ds Max 2018 及以上）"
__ICONLINE__(
    on execute do
    (
        local mv = maxVersion()
        if mv[1] < 20000 then
            (dotNetClass "System.Windows.Forms.MessageBox").Show "批量图生3D 需要 3ds Max 2018 或更高版本，当前 Max 版本过低，无法运行本工具，请改用 2018 及以上版本。" "LiClick 批量图生3D"
        else (
            local appLocal = (dotNetClass "System.Environment").GetFolderPath ((dotNetClass "System.Environment+SpecialFolder").LocalApplicationData)
            local pyF = appLocal + "\\LiClick\\liclick_3dsmax_addon.py"
            if (doesFileExist pyF) then
                python.ExecuteFile pyF
            else
                (dotNetClass "System.Windows.Forms.MessageBox").Show "未找到插件文件，请重新运行 Max工具箱(点击安装).exe" "LiClick"
        )
    )
)
