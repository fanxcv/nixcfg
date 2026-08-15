# Tailscale 组网（与 mac 的 App 版同一账号；远程 SSH / rustdesk 都走 tailnet）
# --hostname：注册到 tailnet 的机器名（tailscaled 默认取系统 hostname，显式指定防漂移）
# useRoutingFeatures = "client"：等价于 tailscale up --accept-routes（允许接受子网路由）
# MagicDNS：tailscaled 默认 --accept-dns=true，经 systemd-resolved 应用（见 networking.nix）；
#   后端 nameserver（119.29.29.29/223.5.5.5）由 headscale 服务端 dns.nameservers 下发
_: {
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.extraDaemonFlags = [ "--hostname=nix-pve" ];
  services.tailscale.useRoutingFeatures = "client";
}
