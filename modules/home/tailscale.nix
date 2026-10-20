# 发行版服务器 Tailscale 接管模块（B 路线：nix 包 + activation 渲染 systemd unit）。
# 二进制始终来自 pkgs.tailscale；removeAptPackage 只负责拆掉接管前遗留的 apt 包。
# state 由 secrets/hosts/<hostName>/tailscale-state.age 恢复，节点名/IP 保持不变。

{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  cfg = config.softwares.tailscaleB;
in
{
  options.softwares.tailscaleB = {
    enable = lib.mkEnableOption "tailscale B 路线（nix 包 + activation 渲染 systemd unit）";
    removeAptPackage = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "接管前系统装过 apt tailscale：先停服务并 dpkg purge 卸载";
    };
  };

  config = lib.mkIf cfg.enable {
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

      ${lib.optionalString cfg.removeAptPackage ''
        # 0) 先停 apt 的 tailscaled（state 文件被占用，覆盖前必须停；服务未运行属预期，幂等跳过）
        /usr/bin/systemctl stop tailscaled 2>/dev/null || true
        # 已安装则 purge：删除 apt 包、配置与原 unit；未安装时幂等跳过
        if dpkg -l tailscale 2>/dev/null | grep -q '^ii'; then
          dpkg -P tailscale
          /usr/bin/systemctl daemon-reload
          echo "[tailscale] apt 包 tailscale 已卸载（nix 接管）"
        fi
      ''}
      # 1) state 解密落位（失败即部署失败——无 if 无兜底，暴露问题）
      umask 077
      mkdir -p "$STATE_DIR"
      "$AGE_BIN" -d -i "$AGE_KEY" -o "$STATE_FILE" ${../../secrets/hosts/${hostName}/tailscale-state.age}
      chmod 600 "$STATE_FILE"

      # 2) wrapper（nix store 路径随升级变化，unit 固定调 wrapper）
      # --port=41641 必须显式传：tailscaled 默认 -port=0（自动随机），云安全组只放行 41641/UDP
      # 时随机端口出网在云边缘被丢，对端收不到直连包只能走 DERP
      cat > /usr/local/bin/tailscaled-nix <<'EOF'
      #!/bin/sh
      exec __TS_BIN__ --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscaled.sock --port=41641
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

      # 3) systemd unit（B 路线：系统层归 Ubuntu，unit 由 nix 渲染${lib.optionalString cfg.removeAptPackage "，覆盖 apt 同名 unit"}）
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

      # 4) 启动 + 登录（state 已含登录态：up 幂等，节点名/IP 保持 ${
        if hostName == "ali-ai" then "ali-sh-3 / 10.1.0.18" else "hc-pro-pve-2 / 10.1.0.34"
      }）
      /usr/bin/systemctl daemon-reload
      /usr/bin/systemctl enable tailscaled > /dev/null 2>&1 || true
      /usr/bin/systemctl restart tailscaled
      for i in $(seq 1 15); do
        "$TS_UP" --login-server=https://headscale.fan-x.fun --accept-routes=true --accept-dns=false > /dev/null 2>&1 && break
        sleep 1
      done
      echo "===> tailscale: $("$TS_UP" status 2>/dev/null | head -1)"
    '';
  };
}
