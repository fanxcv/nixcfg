# KDE 主题切换（tsln 原版）：Catppuccin 全系——Plasma 配色/开机画面/光标、
# fcitx5 皮肤、Konsole 配色（mocha）
# 壁纸不属 catppuccin：为 nixcfg 自定义 assets/kde-wallpaper.jpg
# （见 gui/desktop/plasma/plasma.icon.nix）
# catppuccin 模块在 _common_/default.nix 导入（全平台）
{ lib, ... }:
{
  catppuccin = {
    plasma.enable = lib.mkDefault true;
    fcitx5.enable = lib.mkDefault true;
    konsole.enable = lib.mkDefault true;
    konsole.flavor = lib.mkDefault "mocha";
  };
}
