# 系统级字体（登录界面/控制台/系统服务用；用户层 fontconfig 见 home/fan/_nixos_/i18n/zh-CN/fonts.nix）
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
  ];
}
