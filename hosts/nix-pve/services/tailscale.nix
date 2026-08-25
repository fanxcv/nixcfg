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
    "--login-server=https://headscale.fan-x.fun" # 必须显式：autoconnect 默认连 tailscale.com，headscale key 必被拒
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

  # state 落盘持久化：/var/lib/tailscale bind 到 /persist（impermanence 只开机拷入不回拷，
  # tmpfs 下登录态重启即丢；bind 挂载后 tailscaled 写 state 直接落 /persist，零 unit 改动）
  fileSystems."/var/lib/tailscale" = {
    device = "/persist/var/lib/tailscale";
    fsType = "none";
    options = [ "bind" ];
  };

  # state 灾备（对齐 fan/mi 的 pve 管线语义）：age 加密入库（secrets/hosts/nix-pve/），
  # 仅当 state 缺失时解密落位——平时 bind 持久化已够；此机制用于 /persist 损坏/重建后恢复登录态
  system.activationScripts.tailscaleState = {
    deps = [ "users" ];
    text = ''
      if [ ! -f /var/lib/tailscale/tailscaled.state ]; then
        if ${pkgs.age}/bin/age -d -i /home/fan/.secrets/age-keys.txt \
          -o /tmp/ts-state.tmp ${tools.relative "secrets/hosts/nix-pve/tailscale-nix-pve-state.age"} 2>/tmp/ts-state.err; then
          install -m 0600 -o root -g root /tmp/ts-state.tmp /var/lib/tailscale/tailscaled.state
          echo "tailscale: state 已从仓库种子恢复"
        else
          echo "警告: tailscale state 种子解密失败（autoconnect 将用 authkey 重新注册）：$(cat /tmp/ts-state.err)"
        fi
        rm -f /tmp/ts-state.tmp /tmp/ts-state.err
      fi
    '';
  };
}
