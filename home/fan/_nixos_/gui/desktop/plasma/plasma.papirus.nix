# Papirus 图标（tsln 同款）：刻意恒用 Papirus-Dark 深色图标——tsln 原配置两分支都写
# Papirus-Dark 是特意为之（latte 亮色配色配深色图标），非笔误，本仓保留同款
{ pkgs, ... }:
{
  home.packages = [
    pkgs.papirus-icon-theme
  ];

  programs.plasma.workspace.iconTheme = "Papirus-Dark";
}
