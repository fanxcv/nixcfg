#!/bin/sh
set -eu

# 登录 shell 兜底：镜像构建期已 chsh -s /bin/zsh（Dockerfile），此处幂等双保险
# （防镜像未重建/意外回退；/bin/zsh 是 apt 装的 zsh，比 nix store 路径稳定）
if [ -x /bin/zsh ]; then
  grep -qxF /bin/zsh /etc/shells 2>/dev/null || echo /bin/zsh >> /etc/shells
  [ "$(getent passwd root | cut -d: -f7)" = "/bin/zsh" ] || chsh -s /bin/zsh
fi

# sshd host key：由 nix 激活固定（home/fan/_container_/ssh-host-key.nix，agenix 解密到
# /etc/ssh-host-keys/ 并同步 /etc/ssh/）。本脚本仅兜底：key 缺失（如首次启动/未激活）时生成临时 key，
# 激活后会被覆盖为固定 key；compose 已无 bind mount（key 不再宿主机持久化）
KEYDIR=/etc/ssh-host-keys
if [ ! -s "$KEYDIR/ssh_host_ed25519_key" ]; then
  mkdir -p "$KEYDIR"
  ssh-keygen -q -t ed25519 -f "$KEYDIR/ssh_host_ed25519_key" -N "" -C ""
fi
cp -f "$KEYDIR/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
cp -f "$KEYDIR/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
chmod 600 /etc/ssh/ssh_host_ed25519_key
chmod 644 /etc/ssh/ssh_host_ed25519_key.pub

# nix.conf 兜底：compose 挂载 ./kde-config → /root/.config 遮蔽镜像内 /root/.config/nix/nix.conf
# （重建后 nix-command disabled 报错根因），配置必须系统级 /etc/nix/nix.conf（不在挂载路径）。
# 此处幂等补齐（与 Dockerfile 构建期写入 + flake.nix nixConfig 对齐；新镜像已含，本段仅兜底旧镜像/意外缺失）
NIXCONF=/etc/nix/nix.conf
if ! grep -q 'experimental-features' "$NIXCONF" 2>/dev/null; then
  cat >> "$NIXCONF" <<'EOF'
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
extra-substituters = https://cache.numtide.com https://nix-community.cachix.org
extra-trusted-public-keys = cache.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
experimental-features = nix-command flakes
auto-optimise-store = true
EOF
  echo "[entrypoint] /etc/nix/nix.conf 已补齐（nix-command/flakes + 镜像）"
fi

if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
  exec /usr/sbin/init
fi

exec "$@"
