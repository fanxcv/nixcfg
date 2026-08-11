# Ubuntu/Linux 专属基础包
# 对应 alpine-init.sh install_packages() 的 Ubuntu 分支 + 原 docker/ide/ubuntu/Dockerfile 的 apt 包：
#   zsh 由 _common_/shells.nix 安装（登录 shell 除外，见 Dockerfile 说明）
#   git/vim/curl 在 ../_linux_/base.nix（与 Alpine 共用，不再重复）
#   net-tools/inetutils 原为 apt 包，迁移至此

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    net-tools
    inetutils
  ];
}
