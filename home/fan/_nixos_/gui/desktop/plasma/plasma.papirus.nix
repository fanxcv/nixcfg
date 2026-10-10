# 图标主题：Papirus（tsln 同款，替代原自打包 McMojave-circle）
# latte 亮色用 Papirus-Light，其余 flavor 用 Papirus-Dark
{ config, pkgs, ... }:
{
  home.packages = [
    pkgs.papirus-icon-theme
  ];

  programs.plasma = {
    workspace = {
      iconTheme = if config.catppuccin.flavor == "latte" then "Papirus-Light" else "Papirus-Dark";
    };
  };
}
