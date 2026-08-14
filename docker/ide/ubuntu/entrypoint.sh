#!/bin/sh
set -eu

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

if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
  exec /usr/sbin/init
fi

exec "$@"
