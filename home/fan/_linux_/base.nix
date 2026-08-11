# Linux 系公共基础包（NixOS 真机 / Alpine 服务器 / Linux 容器）
# 原在 _nixos_/base.nix 与 _alpine_/base.nix 重复的三件套，提取到此层统一管理
# mac 系统自带 git/vim/curl，无需安装，故不进 _common_

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    git
    vim
    curl
  ];
}
