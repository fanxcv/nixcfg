# 截图声明（system.defaults.screencapture）
{ config, ... }:
let
  userHome = config.users.users.${config.system.primaryUser}.home;
in
{
  system.defaults.screencapture = {
    # 保存到桌面
    location = "${userHome}/Desktop";
    # PNG 格式
    type = "png";
    # 保留窗口阴影
    disable-shadow = false;
    # 文件名含日期时间
    include-date = true;
    # 记住上次选区
    save-selections = true;
    # 右下角浮动缩略图
    show-thumbnail = true;
    # 目标为文件（非剪贴板/预览）
    target = "file";
  };
}
