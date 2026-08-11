# 显示面板（说明性模块）
# nix-darwin 当前没有声明分辨率/刷新率/亮度/True Tone 的 option；
# 不直接写 com.apple.windowserver 的设备 plist（设备 UUID 变化会破坏显示配置）。
# 显示器设置保持系统面板手动管理。
{
}
