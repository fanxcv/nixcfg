# Alpine 专属基础包
# 对应 alpine-init.sh install_packages() 的 Alpine 分支：
#   apk add zsh git vim curl busybox-extras bash ca-certificates
# zsh 由 ../_common_/shells.nix 安装，bash 由 nix 自带；
# git/vim/curl 在 ../_linux_/base.nix（与 NixOS/Ubuntu 共用，不再重复）

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # 对应 busybox-extras：完整 applet 集合（ps/netstat/ifconfig/wget 等）
    busybox
    # 对应 ca-certificates：Alpine 基础镜像不含 CA 证书，nix/curl 走 HTTPS 必需
    cacert
  ];
}
