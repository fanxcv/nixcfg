# PVE 部署编排（flake packages.<host>：nix run .#<host>）
# 组装：机器层配置渲染（./<host>）+ apply/deploy 脚本（占位符替换）
# 部署目标：PVE 宿主机（Debian 13 trixie，root 用户）
# HM activation 在目标机本机构建（darwin 无法构建 x86_64-linux 闭包），见 deploy.sh
# 注意：flake.nix 里 import 本文件时传 host = "ds2" / "desktop" 等
{ pkgs, lib, host }:
let
  cfg = import ./${host} { inherit pkgs lib; };
  # fan 专属：tailscale state 加密原文件直推，解密在 PVE 侧完成（部署机只传文件，不做实质操作）
  tsState = if cfg ? tailscaleState then toString cfg.tailscaleState else "";
  tsPush = if tsState != "" then ''
    echo "==> [3.5/4] 推送 tailscale state 归档（加密原文件，PVE 侧解密）"
    if [ -f "${tsState}" ]; then
      scp -q "${tsState}" root@$HOST:/tmp/tailscale-state.age
      echo "tailscale state 归档已推送（${tsState}）"
    else
      echo "警告: tailscale state 文件缺失（${tsState}）" >&2
    fi
  '' else "";
  tsApply = if tsState != "" then builtins.readFile ./tailscale-apply.sh else "";
  # lucky 容器（podman quadlet + age 归档；仅 mi）：加密原文件直推，PVE 侧解密
  luckyPush = if cfg ? luckyData then ''
    echo "==> [3.6/4] 推送 lucky 配置归档（加密原文件 → scp，PVE 侧解密）"
    if [ -f "${cfg.luckyData}" ]; then
      scp -q "${cfg.luckyData}" root@$HOST:/tmp/lucky-config.tar.gz.age
      echo "lucky 归档已推送（${cfg.luckyData}）"
    else
      echo "警告: lucky 归档文件缺失（${cfg.luckyData}）" >&2
    fi
  '' else "";
  # apply 段：本机解密 + 解压配置 + quadlet 容器声明 + 迁移（旧手动容器删除，数据在挂载卷无损）
  luckyApply = if cfg ? luckyData then ''
    echo "==> [6.7/7] lucky 容器（Podman Quadlet：nix 宣言 + age 配置，本机解密）"
    mkdir -p /opt/lucky
    /root/.nix-profile/bin/age -d -i /root/.secrets/age-keys.txt /tmp/lucky-config.tar.gz.age > /tmp/lucky-config.tar.gz
    tar xzf /tmp/lucky-config.tar.gz -C /opt/lucky
    rm -f /tmp/lucky-config.tar.gz.age /tmp/lucky-config.tar.gz
    mkdir -p /etc/containers/systemd
    cat > /etc/containers/systemd/lucky.container <<'EOF'
    [Unit]
    Description=Lucky port forward proxy (nix 管理)
    After=network-online.target
    Wants=network-online.target

    [Container]
    Image=docker.1ms.run/gdy666/lucky:2.17.6
    Network=host
    Volume=/opt/lucky/data:/goodluck

    [Service]
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOF
    systemctl daemon-reload
    # 迁移：旧手动容器删除（数据在 /opt/lucky/data 挂载，无损）；quadlet 接管（重启后自动恢复）
    podman rm -f lucky 2>/dev/null || true
    # quadlet 生成 unit 名：podman 5.x 为 lucky.service，4.x 为 podman-lucky.service——动态检测
    LUCKY_UNIT=$(systemctl list-unit-files 2>/dev/null | awk '$2 ~ /generated/ && $1 ~ /(podman-)?lucky\.service/ {print $1; exit}')
    if [ -z "$LUCKY_UNIT" ]; then
      echo "警告: quadlet 未生成 lucky unit（检查 lucky.container 语法）" >&2
    else
      systemctl enable "$LUCKY_UNIT" 2>/dev/null || true
      systemctl restart "$LUCKY_UNIT"
      sleep 3
      if ss -tlnp | grep -qE ":338[0-9]|:339[0-9]"; then
        echo "lucky 已启动（$LUCKY_UNIT），转发端口监听正常"
      else
        echo "警告: lucky 端口未监听（检查 $LUCKY_UNIT）" >&2
      fi
    fi
  '' else "";
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
    if iptables-nft-save -t nat 2>/dev/null | grep -q "tailscale0"; then
      echo "MASQUERADE 规则已生效（tailscale-forward.service）"
    else
      echo "警告: MASQUERADE 规则未生效" >&2
    fi
  '' else "";
  # 部署地址守卫：目标地址唯一事实来源 = nix 声明（ip 字段），传参必须与之一致
  hostIp = lib.head (lib.strings.splitString "/" cfg.ip);
  applySh = pkgs.writeShellScript "${host}-apply" (builtins.replaceStrings
    [ "@PVE_ASSIST_BASE@" "@TAILSCALE@" "@HP_EXTRA@" "@MI_EXTRA@" "@TS_FWD@" "@LUCKY_APPLY@" ]
    [ cfg.pveAssistBase tsApply (if cfg ? hpExtra then cfg.hpExtra else "") (if cfg ? miExtra then cfg.miExtra else "") tsFwd luckyApply ]
    (builtins.readFile ./apply.sh));
in
pkgs.writeShellScriptBin "${host}-deploy" (builtins.replaceStrings
  [ "@FILES@" "@APPLY@" "@HOST@" "@HOST_IP@" "@TS_PUSH@" "@LUCKY_PUSH@" "@SELF_DEPLOY@" ]
  [ "${cfg.files}" "${applySh}" host hostIp tsPush luckyPush (builtins.readFile ./self-deploy.sh) ]
  (builtins.readFile ./deploy.sh))
