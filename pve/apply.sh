#!/usr/bin/env bash
# PVE 系统层 apply（root 远程执行；幂等；失败即退出暴露问题，无静默吞错）
# 占位符 @PVE_ASSIST_BASE@ 由 pve/deploy.nix 构建时替换
# 由 nix run .#<host> 推送至部署目录后执行（HM activate 已在 deploy.sh 完成）
set -euo pipefail
cd "$(dirname "$0")"
BACKUP=/root/pve-backup/$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP"

echo "==> [1/7] root 默认 shell → zsh"
ZSH_BIN=/root/.nix-profile/bin/zsh
if [ -x "$ZSH_BIN" ]; then
  grep -qxF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" >> /etc/shells
  if [ "$(getent passwd root | cut -d: -f7)" != "$ZSH_BIN" ]; then
    chsh -s "$ZSH_BIN" root
    echo "root shell 已切换为 zsh（新登录生效）"
  fi
else
  echo "警告: $ZSH_BIN 不存在，跳过 chsh（HM activate 未装 zsh？）"
fi

echo "==> [2/7] GRUB 内核参数（公共：consoleblank=60；机器专属见渲染 grub 文件）"
cp -a /etc/default/grub "$BACKUP/" 2>/dev/null || true
install -m 0644 grub /etc/default/grub
update-grub
if grep -q "consoleblank=60" /etc/default/grub; then
  echo "consoleblank=60 已写入 GRUB_CMDLINE_LINUX_DEFAULT"
else
  echo "错误: GRUB 参数写入失败" >&2
  exit 1
fi

echo "==> [3/7] apt 换源（CERNET deb822）+ 清理未声明源（enterprise/ceph/tailscale 等）"
cp -a /etc/apt/sources.list.d/. "$BACKUP/" 2>/dev/null || true
cp -a /etc/apt/sources.list "$BACKUP/" 2>/dev/null || true
install -m 0644 debian.sources /etc/apt/sources.list.d/debian.sources
install -m 0644 debian-security.sources /etc/apt/sources.list.d/debian-security.sources
install -m 0644 pve-no-subscription.list /etc/apt/sources.list.d/pve-no-subscription.list
install -m 0644 sources.list /etc/apt/sources.list
# 未声明源（enterprise/ceph/tailscale.list/历史残留）：备份后移除；白名单外一律清掉
for f in /etc/apt/sources.list.d/*; do
  [ -e "$f" ] || continue
  case "$(basename "$f")" in
    debian.sources | debian-security.sources | pve-no-subscription.list) continue ;;
  esac
  mv "$f" "$BACKUP/"
  echo "$(basename "$f") 已移除（未声明源，备份于 $BACKUP ）"
done

echo "==> [4/7] 网络（DNS 直写 + 固定 IP）"
cp -a /etc/resolv.conf "$BACKUP/" 2>/dev/null || true
install -m 0644 resolv.conf /etc/resolv.conf

# 固定 IP（nix 声明：pve/<host>/default.nix 的 ip/gateway → 渲染 static-ip.conf）
# 幂等：awk 替换/插入 vmbr0 段的 address/gateway（dhcp→static 自动转）；不自动重启网络——
# IP 与现状一致时无需；不一致时提示手动 ifreload -a（避免 ssh 断连）
if [ -f static-ip.conf ]; then
  . ./static-ip.conf
  if [ -n "${ip:-}" ] && [ -n "${gateway:-}" ]; then
    cp -a /etc/network/interfaces "$BACKUP/" 2>/dev/null || true
    awk -v ip="$ip" -v gw="$gateway" '
      /^iface / { in_vmbr0 = ($2 == "vmbr0") }
      in_vmbr0 && /^iface vmbr0/ { sub(/ inet dhcp/, " inet static"); print; next }
      in_vmbr0 && /^[[:space:]]*address/ { print "    address " ip; printed_addr = 1; next }
      in_vmbr0 && /^[[:space:]]*gateway/ { print "    gateway " gw; next }
      in_vmbr0 && !printed_addr && /^[[:space:]]*bridge-ports/ { print "    address " ip; print "    gateway " gw; printed_addr = 1 }
      { print }
    ' /etc/network/interfaces > /tmp/interfaces.nixcfg
    if grep -q "iface vmbr0" /tmp/interfaces.nixcfg && grep -q "address $ip" /tmp/interfaces.nixcfg; then
      install -m 0644 /tmp/interfaces.nixcfg /etc/network/interfaces
      echo "固定 IP 已写入（vmbr0: $ip ，网关 $gateway ）"
      if ! grep -q "address $ip" /etc/network/interfaces; then
        echo "警告: 写入后未匹配 address ${ip}（原配置无 vmbr0 静态段？）" >&2
      fi
    else
      echo "警告: /etc/network/interfaces 无 vmbr0 段，固定 IP 跳过（请手动配置）" >&2
    fi
    rm -f /tmp/interfaces.nixcfg
  fi
fi

# sysctl：99-pve.conf（IP 转发——PVE 9 不再自带，升级后转发默认关；tailscale 网关/VM NAT 需开）
install -m 0644 99-pve.conf /etc/sysctl.d/99-pve.conf
sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-pve.conf
if [ "$(sysctl -n net.ipv4.ip_forward)" = "1" ]; then
  echo "IP 转发已开启（net.ipv4.ip_forward=1）"
else
  echo "警告: IP 转发未生效（net.ipv4.ip_forward=$(sysctl -n net.ipv4.ip_forward)）" >&2
fi

echo "==> [5/7] 去订阅 nag + apt update + 安装 pve-assist"
# 去订阅 nag：patch proxmoxlib.js（社区通用法：订阅条件短路为 false）
# 带 marker 幂等；PVE 升级覆盖文件后 marker 消失，下次部署重打；未命中即失败暴露
NAG_FILE=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
if [ -f "$NAG_FILE" ] && ! grep -q "nixcfg-nag-patch" "$NAG_FILE"; then
  cp -a "$NAG_FILE" "$BACKUP/"
  sed -i "s/res\.data\.status\.toLowerCase() !== 'active'/false \/\* nixcfg-nag-patch \*\//" "$NAG_FILE"
  grep -q "nixcfg-nag-patch" "$NAG_FILE" || { echo "错误: 订阅 nag patch 未命中（PVE 版本可能已改代码）" >&2; exit 1; }
  echo "订阅 nag 已 patch（备份于 $BACKUP ）"
else
  echo "订阅 nag patch 已存在或文件缺失，跳过"
fi
apt-get update
# pve-assist 安装（install.sh 同款：gz 下载 + SHA256 校验，失败即退出）
curl -fsSL "@PVE_ASSIST_BASE@/SHA256SUMS" -o /tmp/pa-sha256
curl -fsSL "@PVE_ASSIST_BASE@/pve-assist-linux-amd64.gz" | gzip -dc > /tmp/pa-bin
EXPECTED=$(awk '$2 == "pve-assist-linux-amd64" || $2 == "*pve-assist-linux-amd64" {print $1; exit}' /tmp/pa-sha256)
echo "$EXPECTED  /tmp/pa-bin" | sha256sum -c - >/dev/null
install -m 0755 /tmp/pa-bin /usr/local/bin/pve-assist
# 去订阅 nag（pve-assist 自带 marker 补丁，stale 时自动修复；失败即退出暴露）
pve-assist --repair-subscription-if-stale

# ifupdown2 × python3.12 兼容修复（readfp 已移除 → read_file；某版本组合开机网络起不来，幂等）
IFUPDOWN2_PARSER=/usr/lib/python3/dist-packages/ifupdown2/ifupdown2lib/ifupdown_parser.py
if [ -f "$IFUPDOWN2_PARSER" ] && grep -q "readfp" "$IFUPDOWN2_PARSER"; then
  sed -i "s/\.readfp(/.read_file(/" "$IFUPDOWN2_PARSER"
  echo "警告: ifupdown2 readfp 已修复（python3.12 兼容），重启网络后生效"
fi

echo "==> [6/7] modprobe / modules 收编（声明的写入，废弃的删除）"
CHANGED=0
if [ -d modprobe ] && ls modprobe/*.conf >/dev/null 2>&1; then
  for f in modprobe/*.conf; do
    DEST="/etc/modprobe.d/$(basename "$f")"
    if ! cmp -s "$f" "$DEST" 2>/dev/null; then
      cp -a "$DEST" "$BACKUP/" 2>/dev/null || true
      install -m 0644 "$f" "$DEST"
      CHANGED=1
      echo "modprobe 更新: $(basename "$f")"
    fi
  done
else
  echo "警告: modprobe 渲染目录缺失（渲染异常？）"
fi
# 已废弃的 modprobe 文件（不再直通等）：备份后删除
if [ -f obsolete-modprobe ]; then
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    DEST="/etc/modprobe.d/$name"
    if [ -e "$DEST" ]; then
      cp -a "$DEST" "$BACKUP/" 2>/dev/null || true
      rm -f "$DEST"
      CHANGED=1
      echo "modprobe 移除（已废弃）: $name"
    fi
  done < obsolete-modprobe
fi
# 开机加载模块（/etc/modules）
if [ -f modules ] && ! cmp -s modules /etc/modules; then
  cp -a /etc/modules "$BACKUP/" 2>/dev/null || true
  install -m 0644 modules /etc/modules
  CHANGED=1
  echo "/etc/modules 已更新"
fi
if [ "$CHANGED" = "1" ]; then
  update-initramfs -u
  echo "initramfs 已重建（modprobe/modules 变更，重启后生效）"
else
  echo "modprobe/modules 无变化，跳过 initramfs"
fi

echo "==> [6.2/7] sshd 加固（禁用密码登录，仅公钥；drop-in 由 nixcfg 写入）"
SSH_DROPIN=/etc/ssh/sshd_config.d/00-nix-hardening.conf
if [ ! -s /root/.ssh/authorized_keys ]; then
  echo "警告: /root/.ssh/authorized_keys 为空，跳过 sshd 加固（防锁死）" >&2
elif ! grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d' /etc/ssh/sshd_config; then
  echo "警告: sshd_config 未 Include sshd_config.d，跳过加固" >&2
else
  mkdir -p /etc/ssh/sshd_config.d
  cat > "$SSH_DROPIN" <<'SSHD'
PasswordAuthentication no
KbdInteractiveAuthentication no
SSHD
  chmod 644 "$SSH_DROPIN"
  if /usr/sbin/sshd -t; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || echo "警告: sshd reload 失败（配置已写入，下次重启生效）" >&2
    echo "sshd 加固已生效（PasswordAuthentication no）"
  else
    rm -f "$SSH_DROPIN"
    echo "警告: sshd -t 校验失败，已移除 drop-in" >&2
  fi
fi

@TAILSCALE@

@HP_EXTRA@

@MI_EXTRA@

@TS_FWD@

@LUCKY_APPLY@

# PVE apply.sh 是跨 Nix 边界的静态 shell；镜像域名唯一来源为 tools/config.nix.dockerRegistryMirrors，改入口后需同步此块。
echo "==> [6.8/7] podman 镜像加速（registries.conf.d drop-in，与 docker daemon.json 同域名）"
mkdir -p /etc/containers/registries.conf.d
cat > /etc/containers/registries.conf.d/mirror.conf <<'MIRROR'
[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "docker.xuanyuan.me"

[[registry.mirror]]
location = "docker.1ms.run"

[[registry.mirror]]
location = "docker.m.daocloud.io"
MIRROR
echo "podman registries.conf.d/mirror.conf 已写入（docker.io → 3 个国内 mirror）"

echo "==> [6.9/7] nix 自动 GC（30 天保留 + 定期硬链接优化）"
# 幂等：nix.conf 加 auto-optimise-store（store 硬链接去重），daemon 重启生效
if [ -f /etc/nix/nix.conf ] && ! grep -q "auto-optimise-store" /etc/nix/nix.conf; then
  echo "auto-optimise-store = true" >> /etc/nix/nix.conf
  systemctl restart nix-daemon 2>/dev/null || true  # || true：nix.conf 无变时不重启；daemon 不在也容错
fi
# systemd timer：每周 nix-collect-garbage --delete-older-than 30d（nix 二进制绝对路径，不在系统 PATH）
cat > /etc/systemd/system/nix-gc.service <<'UNIT'
[Unit]
Description=Nix garbage collection
After=network.target
[Service]
Type=oneshot
ExecStart=/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 30d
UNIT
cat > /etc/systemd/system/nix-gc.timer <<'UNIT'
[Unit]
Description=Weekly nix garbage collection
[Timer]
OnCalendar=weekly
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now nix-gc.timer >/dev/null 2>&1 || true  # || true：幂等（已启用）
systemctl is-active nix-gc.timer

pveversion
if grep -rq "enterprise" /etc/apt/sources.list.d/ 2>/dev/null; then
  echo "警告: 仍有 enterprise 源残留" >&2
else
  echo "enterprise 源已清除"
fi
echo "--- DNS（/etc/resolv.conf）---"
cat /etc/resolv.conf
zsh --version
[ -d /root/.oh-my-zsh ] && echo "oh-my-zsh OK"
ls -l /usr/local/bin/pve-assist
echo "完成。新开终端生效（root shell 已切 zsh）。"
