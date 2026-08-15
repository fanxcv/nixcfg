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

  # MagicDNS 生效机制：tailscaled 默认 --accept-dns=true，Linux 上需经 systemd-resolved
  # 应用 headscale 下发的 DNS 配置（NM 默认接管 resolv.conf 会与 tailscaled 冲突）
  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

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
