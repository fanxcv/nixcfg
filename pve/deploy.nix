# PVE 部署编排（flake packages.<host>：nix run .#<host> [ip]）
# 组装：机器层配置渲染（./<host>）+ apply/deploy 脚本（占位符替换）
# 部署目标：PVE 宿主机（Debian 13 trixie，root 用户）
# HM activation 在目标机本机构建（darwin 无法构建 x86_64-linux 闭包），见 deploy.sh
# 注意：flake.nix 里 import 本文件时传 host = "ds2" / "desktop" 等
{ pkgs, lib, host }:
let
  cfg = import ./${host} { inherit pkgs lib; };
  # fan 专属：tailscale state 从 secrets 解密推送（其他机器 tsState 为空 → 两段均为空）
  tsState = if cfg ? tailscaleState then toString cfg.tailscaleState else "";
  tsPush = if tsState != "" then ''
    echo "==> [4.5/5] 推送 tailscale state（fan 专属：secrets 解密 → scp）"
    if [ -f "${tsState}" ]; then
      age -d -i "$HOME/.secrets/age-keys.txt" "${tsState}" > /tmp/ts-state
      scp -q /tmp/ts-state root@$HOST:/tmp/tailscale-state
      rm -f /tmp/ts-state
      echo "tailscale state 已推送（fan 身份归档）"
    else
      echo "警告: tailscale state 文件缺失（${tsState}）" >&2
    fi
  '' else "";
  tsApply = if tsState != "" then builtins.readFile ./tailscale-apply.sh else "";
  # tailscale 转发规则（仅 fan/mi 网关机）：写 rules + systemd unit（幂等：先删后插，重启自动恢复）
  tsFwd = if (cfg ? tailscaleForward && cfg.tailscaleForward) then ''
    echo "==> [6.6/7] tailscale 转发规则（nix 管理：MASQUERADE + FORWARD ACCEPT）"
    mkdir -p /etc/iptables
    install -m 0644 tailscale-forward.rules /etc/iptables/tailscale-forward.rules
    cat > /etc/systemd/system/tailscale-forward.service <<'EOF'
    [Unit]
    Description=Tailscale forward rules (nix 管理)
    After=tailscaled.service
    Wants=tailscaled.service
    [Service]
    Type=oneshot
    ExecStartPre=/bin/sh -c '/usr/sbin/iptables-nft -t nat -D POSTROUTING -o tailscale0 -j MASQUERADE 2>/dev/null || true'
    ExecStartPre=/bin/sh -c '/usr/sbin/iptables-nft -D FORWARD -o tailscale0 -j ACCEPT 2>/dev/null || true'
    ExecStart=/usr/sbin/iptables-nft-restore --noflush /etc/iptables/tailscale-forward.rules
    RemainAfterExit=yes
    [Install]
    WantedBy=multi-user.target
    EOF
    systemctl daemon-reload
    systemctl enable --now tailscale-forward.service
    if iptables-nft -t nat -L POSTROUTING -n | grep -q "tailscale0"; then
      echo "MASQUERADE 规则已生效（tailscale-forward.service）"
    else
      echo "警告: MASQUERADE 规则未生效" >&2
    fi
  '' else "";
  applySh = pkgs.writeShellScript "${host}-apply" (builtins.replaceStrings
    [ "@PVE_ASSIST_BASE@" "@TAILSCALE@" "@HP_EXTRA@" "@TS_FWD@" ]
    [ cfg.pveAssistBase tsApply (if cfg ? hpExtra then cfg.hpExtra else "") tsFwd ]
    (builtins.readFile ./apply.sh));
in
pkgs.writeShellScriptBin "${host}-deploy" (builtins.replaceStrings
  [ "@FILES@" "@APPLY@" "@HOST@" "@TS_PUSH@" ]
  [ "${cfg.files}" "${applySh}" host tsPush ]
  (builtins.readFile ./deploy.sh))
