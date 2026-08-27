# Papirus 图标（tsln 同款；latte 亮色配亮色 Papirus——tsln 原配置两分支都写 Papirus-Dark 属笔误）
{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.papirus-icon-theme
  ];

  programs.plasma.workspace.iconTheme =
    if config.catppuccin.flavor == "latte" then "Papirus" else "Papirus-Dark";
}
