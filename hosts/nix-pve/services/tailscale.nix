# Tailscale 组网（与 mac 的 App 版同一 headscale；远程 SSH / rustdesk 都走 LAN+tailnet 双路）
# --hostname：注册到 tailnet 的机器名（tailscale up/login 的参数；tailscaled 本身无此 flag，
#   2026-08 nixpkgs 更新后 tailscaled 1.98.10 直接 INVALIDARGUMENT 拒绝——不得放 extraDaemonFlags）
# 登录机制：oneshot（tailscale-headscale）幂等登录——status 成功即跳过；
#   登录态在 /var/lib/tailscale（impermanence persist，见 immutable.nix），authkey 走 agenix 系统域
# useRoutingFeatures = "client"：等价于 tailscale up --accept-routes（允许接受子网路由）
# MagicDNS：tailscaled 默认 --accept-dns=true，经 systemd-resolved 应用（见 networking.nix）；
#   后端 nameserver（119.29.29.29/223.5.5.5）由 headscale 服务端 dns.nameservers 下发
# authkey 轮换：headscale 上 headscale preauthkeys create -r -e 0 生成 → 写入
#   secrets/source/headscale-auth-key.txt → ./secrets/encrypt.sh --force 重加密 → 重部署
{ tools, ... }:
let
  headscaleUrl = "https://headscale.fan-x.fun";
in
{
  services.tailscale.enable = true;
  services.tailscale.openFirewall = true;
  services.tailscale.useRoutingFeatures = "client";

  # authkey 系统域解密（root 读；跟 comin-token 同机制）
  age.secrets."headscale-auth-key" = {
    file = tools.relative "secrets/headscale-auth-key.txt.age";
    path = "/run/agenix/headscale-auth-key";
    mode = "0400";
  };

  # 幂等登录（boot 每次跑，已登录则只收敛节点名/路由/DNS）
  systemd.services.tailscale-headscale = {
    description = "Tailscale headscale 登录（幂等）";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ts=/run/current-system/sw/bin/tailscale
      key=/run/agenix/headscale-auth-key
      server=${headscaleUrl}
      if $ts status >/dev/null 2>&1; then
        echo "tailscale: 已登录，收敛节点名/路由/DNS"
        $ts set --hostname=nix-pve --accept-routes=true --accept-dns=true || \
          echo "警告: tailscale set 失败（稍后手动：tailscale set --hostname=nix-pve --accept-routes=true --accept-dns=true）"
      elif [ -f "$key" ]; then
        echo "tailscale: headscale 登录（$server，节点名 nix-pve）"
        $ts login --login-server="$server" --authkey "$(cat "$key")" \
          --hostname=nix-pve --accept-routes=true --accept-dns=true || \
          echo "警告: headscale 登录失败（服务器可达？authkey 过期？重新生成后重部署）"
      else
        echo "警告: /run/agenix/headscale-auth-key 缺失，未自动登录"
        echo "      （headscale preauthkeys create -r 生成 → secrets/source/ → encrypt.sh）"
      fi
    '';
  };
}
