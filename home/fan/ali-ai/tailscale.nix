# Tailscale 接管（docker 容器 → nix 原生，B 路线）
# 背景：原 docker 容器（/opt/tailscale，host 网络 + privileged）已停用；
#   state 从 /opt/tailscale/data/tailscaled.state 提取，age 加密入 secrets/hosts/ali-ai/tailscale-state.age
#   （仓库 mi/fan/nix-pve 同款机制：state 含 node key，恢复后节点名/IP 不变——10.1.0.18）
# 登录服务器：headscale.fan-x.fun（自建，必须显式 --login-server，否则默认 tailscale.com 被拒）
# 系统层归 Ubuntu：systemd unit 由 activation 写（B 路线，不碰发行版包管理）
# DNS 保守：--accept-dns=false（生产服务器 DNS 保持 Ubuntu 默认，headscale 只做组网）

{
  lib,
  pkgs,
  ...
}:
{
  # 不装 home.packages（避免 nix profile 的 tailscale 与 wrapper 抢 PATH）；
  # 二进制经 activation 的 wrapper（/usr/local/bin/tailscale + tailscaled-nix）暴露，
  # 升级 tailscale 包后 activation 重写 wrapper 即生效
  home.activation.setupTailscale = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TS_BIN="${pkgs.tailscale}/bin/tailscaled"
    TS_UP="${pkgs.tailscale}/bin/tailscale"
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    STATE_DIR=/var/lib/tailscale
    STATE_FILE=$STATE_DIR/tailscaled.state

    # 1) state 解密落位（失败即部署失败——无 if 无兜底，暴露问题）
    umask 077
    mkdir -p "$STATE_DIR"
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$STATE_FILE" ${../../..}/secrets/hosts/ali-ai/tailscale-state.age
    chmod 600 "$STATE_FILE"

    # 2) wrapper（nix store 路径随升级变化，unit 固定调 wrapper）
    cat > /usr/local/bin/tailscaled-nix <<'EOF'
    #!/bin/sh
    exec __TS_BIN__ --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscaled.sock
    EOF
    sed -i "s|__TS_BIN__|$TS_BIN|" /usr/local/bin/tailscaled-nix
    chmod +x /usr/local/bin/tailscaled-nix

    # 2b) CLI wrapper：root 的 XDG_RUNTIME_DIR=/run/user/0 会让 CLI 默认找 /run/user/0/tailscaled.sock
    #     （tailscaled 是系统服务监听 /run，不随登录会话）→ 固定 --socket=/var/run/tailscaled.sock
    cat > /usr/local/bin/tailscale <<EOF
    #!/bin/sh
    exec $TS_UP --socket=/var/run/tailscaled.sock "\$@"
    EOF
    chmod +x /usr/local/bin/tailscale

    # 3) systemd unit（B 路线：系统层归 Ubuntu，unit 由 nix 渲染）
    cat > /etc/systemd/system/tailscaled.service <<'EOF'
    [Unit]
    Description=Tailscale node agent (nix-managed)
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=notify
    ExecStart=/usr/local/bin/tailscaled-nix
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=1048576

    [Install]
    WantedBy=multi-user.target
    EOF

    # 4) 启动 + 登录（state 已含登录态：up 幂等，节点名/IP 保持 ali-sh-3 / 10.1.0.18）
    /usr/bin/systemctl daemon-reload
    /usr/bin/systemctl enable tailscaled > /dev/null 2>&1 || true
    /usr/bin/systemctl restart tailscaled
    for i in $(seq 1 15); do
      "$TS_UP" --login-server=https://headscale.fan-x.fun --accept-routes=true --accept-dns=false > /dev/null 2>&1 && break
      sleep 1
    done
    echo "===> tailscale: $("$TS_UP" status 2>/dev/null | head -1)"
  '';
}
