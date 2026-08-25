#!/usr/bin/env bash
# PVE 服务器自部署入口（由 mac 部署 [5/5] 推送到 /root/self-deploy.sh）
# 用法（服务器上）：/root/self-deploy.sh [host]
#   host 默认取本机 hostname；流程：clone/pull 仓库 → nix run .#<host> -- --self
# 前置（首次 mac 部署已装）：/root/.secrets/age-keys.txt + /root/.git-credentials + nix
set -euo pipefail

if [ ! -d /root/nixcfg/.git ]; then
  echo "==> 仓库不存在，clone 到 /root/nixcfg"
  command -v git >/dev/null 2>&1 || apt-get install -y git
  git config --global credential.helper store
  git clone http://git.fan-x.fun/fan/nixcfg.git /root/nixcfg
fi

cd /root/nixcfg
git pull --ff-only
echo "==> 仓库已同步: $(git log --oneline -1)"

HOST="${1:-$(hostname)}"
export PATH="/usr/local/bin:/nix/var/nix/profiles/default/bin:/root/.nix-profile/bin:$PATH"
nix run ".#${HOST}" -- --self
