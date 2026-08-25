# KDE Plasma RDP 远程桌面（krdp）：Windows 远程桌面（mstsc）直连 nix-pve
# 机制：kdePackages.krdp 提供 krdpserver，镜像当前登录的 Plasma 会话（Wayland 原生，非独立登录会话）
# 服务持久化在 home 层（home/fan/nix-pve/krdp.nix）：systemd user unit 自启 + 证书自动生成 + portal 预授权；
# 本文件只负责：包安装 + 防火墙放行
# 连接：Windows mstsc 填 nix-pve:3389（LAN 10.2.241.39 / tailnet 10.1.0.21），凭据见 home 层模块
{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.kdePackages.krdp
  ];

  # RDP 默认端口 3389/TCP 放行（tailscale 接口已整体放行，见 networking.nix trustedInterfaces；
  # 这里补局域网/VM 网卡口。KCM 改端口后需同步改这里）
  networking.firewall.allowedTCPPorts = [ 3389 ];
}
