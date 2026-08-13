#!/usr/bin/env bash
# 升级 nixpkgs 到国内镜像已同步的最新版本（保证构建命中 USTC/TUNA 缓存）
# 用法：./scripts/update-nixpkgs.sh [镜像]（默认 USTC，可换 TUNA：https://mirrors.tuna.tsinghua.edu.cn/nix-channels）
set -euo pipefail
cd "$(dirname "$0")/.."

mirror="${1:-https://mirrors.ustc.edu.cn/nix-channels}"
echo "查询 $mirror 的 nixos-unstable 同步版本..."
rev=$(curl -fsSL --max-time 300 "$mirror/nixos-unstable/nixexprs.tar.xz" \
  | tar -xJ --to-stdout '*/.git-revision')
echo "镜像同步 rev: $rev"

cur=$(grep -oE 'rev=[0-9a-f]{40}' flake.nix | head -1 | cut -d= -f2 || true)
if [ "$cur" = "$rev" ]; then
  echo "已是最新（与镜像同步点一致），无需更新"
  exit 0
fi

[ -n "$cur" ] && echo "当前 rev: $cur"
sed -i '' "s/rev=[0-9a-f]\{40\}/rev=$rev/" flake.nix
echo "已更新 flake.nix，重新锁定..."
nix flake lock
echo "完成。构建将命中镜像缓存；如遇 gh-proxy 限流失败可稍后重试。"
