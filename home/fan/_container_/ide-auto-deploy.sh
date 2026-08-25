#!/bin/sh
# ide 容器配置自动部署（pull 轮询模型，轻量替代 comin——comin 只认 nixos/darwin 配置输出且需 NixOS 系统）
# 由 ide-auto-deploy.nix 激活时安装到 /usr/local/bin/（sed 替换 @hostName@）
# 逻辑：/root/nixcfg（compose bind mount，不 clone）git pull --ff-only → HEAD 变更才 nix run .#<hostName>
# 状态：/var/lib/ide-auto-deploy/last 记录上次激活 commit；容器重建后清空 → 首次轮询自动激活
# 代理：ide-si 的 all_proxy 由 sysenv.nix 写 /etc/environment.d/zz-ide-proxy.conf，systemd 服务启动自动注入，无需重复处理
# 失败重试：激活失败不更新 last，下次轮询自动重试
set -eu
export GIT_TERMINAL_PROMPT=0
REPO=/root/nixcfg
STATE=/var/lib/ide-auto-deploy
mkdir -p "$STATE"
cd "$REPO" || { echo "[ide-auto-deploy] $REPO 不存在"; exit 0; }

git pull --ff-only -q 2>/dev/null || true
HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")
[ -n "$HEAD" ] || { echo "[ide-auto-deploy] 无法读取 HEAD"; exit 0; }
LAST=$(cat "$STATE/last" 2>/dev/null || echo "")
if [ "$HEAD" = "$LAST" ]; then
  exit 0
fi

echo "===> [ide-auto-deploy] HEAD 变更 ${LAST:+$LAST → }$HEAD，激活 .#@hostName@"
# 部分 derivation 构建期联网下载（__noChroot）；nix 禁止 __noChroot 与 sandbox 并存 → 本次构建关沙箱
# --accept-flake-config：接受 flake.nix 的 nixConfig（USTC/TUNA/SJTU 镜像），保存到 trusted-settings.json 后永久生效
if nix run --accept-flake-config --option sandbox false .#@hostName@; then
  echo "$HEAD" > "$STATE/last"
  echo "===> [ide-auto-deploy] 激活成功（$HEAD）"
else
  echo "===> [ide-auto-deploy] 激活失败（下次轮询重试）"
fi
