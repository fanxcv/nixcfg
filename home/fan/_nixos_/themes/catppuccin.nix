# KDE 主题切换（tsln 原版）：Catppuccin 全系——Plasma 配色/开机画面/光标、
# 壁纸（桌面+锁屏，模块 modules/home/catppuccin/wallpaper.nix）、
# fcitx5 皮肤、Konsole 配色（mocha）
# catppuccin 模块在 _common_/default.nix 导入（全平台）
{ lib, ... }:
{
  catppuccin = {
    plasma.enable = lib.mkDefault true;
    wallpaper.enable = lib.mkDefault true;
    fcitx5.enable = lib.mkDefault true;
    konsole.enable = lib.mkDefault true;
    konsole.flavor = lib.mkDefault "mocha";
  };
}
