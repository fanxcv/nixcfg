# 网络：NetworkManager（Plasma 托盘集成）+ nftables 防火墙 + tailscale 组网
{ lib, config, ... }:
let
  inherit (config.services) tailscale;
in
{
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # NTP：国内源优先（PVE 内网/国内网络环境）
  networking.timeServers = [
    "pool.ntp.org"
    "ntp.aliyun.com"
    "ntp.tencent.com"
  ];

  # Tailscale 接口放行（服务见 services/tailscale.nix）
  networking.firewall.trustedInterfaces = [
    tailscale.interfaceName
  ];
}
