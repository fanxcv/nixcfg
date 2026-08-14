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
  # ---- 配置激活：容器重建后 home 配置丢失（镜像内无激活产物），恢复最新配置 ----
  # nix store 为持久卷（nix-store:/nix），重建后增量构建，耗时短；失败不阻塞启动（轮询/下次重建重试）
  MACHINE="${IDE_MACHINE:-ide-si}"   # 机器名由 compose environment 指定（si/lenovo 各配各的）
  # 代理：仅 ide-si 存在 zz-ide-proxy.conf（environment.d 格式含非 shell 行如 JAVA_TOOL_OPTIONS，
  #   不能整体 source——set -e 下 source 失败会退出；按 KEY 精确提取）
  for k in all_proxy ALL_PROXY http_proxy HTTP_PROXY https_proxy HTTPS_PROXY no_proxy NO_PROXY; do
    v=$(sed -n "s/^$k=//p" /etc/environment.d/zz-ide-proxy.conf 2>/dev/null | head -1)
    [ -n "$v" ] && export "$k=$v"
  done
  export GIT_TERMINAL_PROMPT=0
  if [ -d /root/nixcfg ]; then
    cd /root/nixcfg
    git pull --ff-only -q 2>/dev/null || true
    echo "===> [entrypoint] nix run .#${MACHINE} ..."
    if nix run ".#${MACHINE}"; then
      echo "===> [entrypoint] 激活成功（$(git rev-parse --short HEAD)）"
    else
      echo "===> [entrypoint] 激活失败（容器照常启动；ide-auto-deploy 轮询会重试）"
    fi
  else
    echo "===> [entrypoint] 未找到 /root/nixcfg（compose 未挂载仓库），跳过激活"
  fi
  exec /usr/sbin/init
fi

exec "$@"
