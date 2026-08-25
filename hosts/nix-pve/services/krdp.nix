# KDE Plasma RDP 远程桌面（krdp）：Windows 远程桌面（mstsc）直连 nix-pve
# 机制：kdePackages.krdp 提供 krdpserver，镜像当前登录的 Plasma 会话（Wayland 原生，非独立登录会话）
# 使用：系统设置 → 远程桌面 → RDP → 开启「远程桌面」+ 设置用户名/密码（首连需在桌面现场点一次 portal 授权确认框）
# 连接：Windows mstsc 填 nix-pve 地址:3389（或 KCM 里改的端口），凭据即 KCM 里设的用户名/密码
{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.kdePackages.krdp
  ];

  # RDP 默认端口 3389/TCP 放行（tailscale 接口已整体放行，见 networking.nix trustedInterfaces；
  # 这里补局域网/VM 网卡口。KCM 改端口后需同步改这里）
  networking.firewall.allowedTCPPorts = [ 3389 ];
}
