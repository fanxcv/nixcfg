#!/bin/sh
set -eu

# sshd host key 持久化：复用宿主机 docker/ide/ssh-keys/ 的密钥（bind mount 到 /etc/ssh-host-keys），
# 容器重建后 host key 不变，客户端 known_hosts 不会失配（REMOTE HOST IDENTIFICATION HAS CHANGED）
# 首次启动自动生成；重建后文件已存在则跳过生成，直接同步到 /etc/ssh/ 供 sshd 使用
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
