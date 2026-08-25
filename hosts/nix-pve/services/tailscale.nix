# Tailscale 组网（与 mac 的 App 版同一 headscale；远程 SSH / rustdesk 双路）
# 登录机制：模块原生 authKeyFile（tailscaled-autoconnect 幂等轮询：NeedsLogin 时
#   tailscale up --auth-key，Running 即停）；--hostname 属 up/set 参数（tailscaled 无此 flag，
#   2026-08 nixpkgs 更新后 1.98.10 直接 INVALIDARGUMENT——不得放 extraDaemonFlags）
# state 持久化：--state 直写 /persist/var/lib/tailscale（impermanence 只开机拷入不回拷，
#   tmpfs 下的登录态重启即丢 → 每次重启重新注册 → headscale 重名加随机后缀 → IP 漂移；
#   落 /persist 后登录态跨重启稳定，节点名/IP 固定）
# MagicDNS：tailscaled 默认 --accept-dns=true，经 systemd-resolved 应用（见 networking.nix）；
#   后端 nameserver（119.29.29.29/223.5.5.5）由 headscale 服务端 dns.nameservers 下发
# authkey 轮换：headscale 上 headscale preauthkeys create -r -e 0 生成 → 写入
#   secrets/source/headscale-auth-key.txt → ./secrets/encrypt.sh --force 重加密 → 重部署
{ tools, lib, pkgs, ... }:
{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "client";

  # 模块原生登录：authKeyFile 非空 → tailscaled-autoconnect 自动 up（幂等轮询）
  services.tailscale.authKeyFile = "/run/agenix/headscale-auth-key";
  services.tailscale.extraUpFlags = [
    "--hostname=nix-pve"
    "--accept-routes=true"
    "--accept-dns=true"
  ];
  # 已登录机器也收敛节点名/路由/DNS（tailscaled-set oneshot）
  services.tailscale.extraSetFlags = [
    "--hostname=nix-pve"
    "--accept-routes=true"
    "--accept-dns=true"
  ];

  # authkey 系统域解密（root 读；跟 comin-token 同机制）
  age.secrets."headscale-auth-key" = {
    file = tools.relative "secrets/headscale-auth-key.txt.age";
    path = "/run/agenix/headscale-auth-key";
    mode = "0400";
  };

  # state 落盘持久化：重写 tailscaled 的 --state（默认 /var/lib/tailscale 在 tmpfs）
  systemd.services.tailscaled.serviceConfig.ExecStart = lib.mkForce [
    "${pkgs.tailscale}/bin/tailscaled --state=/persist/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock --port=\${PORT} \${FLAGS}"
  ];
}
