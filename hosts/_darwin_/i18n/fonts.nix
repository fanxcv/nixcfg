# 系统字体：Monaspace 全家桶（Nerd Font）
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.monaspace
  ];
}
