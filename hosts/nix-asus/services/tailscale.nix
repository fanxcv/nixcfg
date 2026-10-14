# Tailscale 组网（与 mac 的 App 版同一 headscale；远程 SSH / rustdesk 双路）
# 登录机制：模块原生 authKeyFile（tailscaled-autoconnect 幂等轮询：NeedsLogin 时
#   tailscale up --auth-key，Running 即停）；--hostname 属 up/set 参数（tailscaled 无此 flag）
# state 持久化：--state 直写 /persist/var/lib/tailscale（impermanence 只开机拷入不回拷，
#   tmpfs 下的登录态重启即丢 → 每次重启重新注册 → headscale 重名加随机后缀 → IP 漂移）
{
  tools,
  ...
}:
{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "client";

  # 模块原生登录：authKeyFile 非空 → tailscaled-autoconnect 自动 up（幂等轮询）
  services.tailscale.authKeyFile = "/run/agenix/headscale-auth-key";
  services.tailscale.extraUpFlags = [
    "--hostname=nix-asus"
    "--login-server=https://headscale.fan-x.fun" # 必须显式：autoconnect 默认连 tailscale.com，headscale key 必被拒
    "--accept-routes=true"
    "--accept-dns=true"
  ];
  # 已登录机器也收敛节点名/路由/DNS（tailscaled-set oneshot）
  services.tailscale.extraSetFlags = [
    "--hostname=nix-asus"
    "--accept-routes=true"
    "--accept-dns=true"
  ];

  # authkey 系统域解密（root 读；与 nix-lenovo/nix-pve 共用同一 preauth key）
  age.secrets."headscale-auth-key" = {
    file = tools.relative "secrets/headscale-auth-key.age";
    path = "/run/agenix/headscale-auth-key";
    mode = "0400";
  };

  # state 落盘持久化：/var/lib/tailscale bind 到 /persist
  fileSystems."/var/lib/tailscale" = {
    device = "/persist/var/lib/tailscale";
    fsType = "none";
    options = [ "bind" ];
  };
}
