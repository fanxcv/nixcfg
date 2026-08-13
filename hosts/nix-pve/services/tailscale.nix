# Tailscale 组网（与 mac 的 App 版同一账号；远程 SSH / rustdesk 都走 tailnet）
_: {
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
}
