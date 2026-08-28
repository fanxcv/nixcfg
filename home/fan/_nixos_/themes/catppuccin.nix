# KDE 主题切换（帖子方案 blog.sotkg.com/2025/08/kde-customization）：Catppuccin 全部禁用
# 桌面主题由 plasma.theme.nix 接管（Fedora 全局主题 + Moe 颜色/Plasma 样式 + Colloid 图标 + Hoshino 光标）
# catppuccin 模块仍在 _common_/default.nix 导入（全平台），这里用 mkForce false 强制关 NixOS 桌面主题
{ lib, ... }:
{
  catppuccin = {
    plasma.enable = lib.mkForce false;
    fcitx5.enable = lib.mkForce false;
    wallpaper.enable = lib.mkForce false;
    konsole.enable = lib.mkForce false;
  };
}
