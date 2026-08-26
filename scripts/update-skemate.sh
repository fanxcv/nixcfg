#!/usr/bin/env bash
# 升级 skemate-latest input：curl 官方 latest.json 取新版本号 → 改写 flake.nix 的 ?v= → nix flake update
# 原理：URL 带 ?v=版本号，版本号变化 → URL 变化 → nix fetcher-cache key 变化 → 必然重新下载，
#       绕过 CDN/本地缓存（旧坑：URL 不变时 nix flake update 跳过、--refresh 无效、各机器缓存旧内容致 narHash mismatch）
set -euo pipefail

cd "$(dirname "$0")/.."

FLAKE_NIX=flake.nix
API_URL="https://w-apis.qksxin.com/terminal/latest.json"

# 1. 拉取官方最新版本号
new_ver="$(curl -fsSL "$API_URL" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[[ -n "$new_ver" ]] || { echo "错误: 无法从 $API_URL 解析 version" >&2; exit 1; }

# 2. 读当前 flake.nix 里的版本号
cur_ver="$(sed -n 's/.*latest\.json?v=\([0-9][^"]*\)".*/\1/p' "$FLAKE_NIX" | head -1)"
[[ -n "$cur_ver" ]] || { echo "错误: flake.nix 未找到 latest.json?v= 版本号" >&2; exit 1; }

if [[ "$new_ver" == "$cur_ver" ]]; then
  echo "skemate 已是最新（$new_ver ），无需更新"
  exit 0
fi

# 3. 改写 flake.nix 的 ?v=（-i.bak 兼容 GNU/BSD sed，随后清理）
sed -i.bak "s/latest\.json?v=$cur_ver/latest.json?v=$new_ver/" "$FLAKE_NIX"
rm -f "$FLAKE_NIX.bak"
echo "flake.nix: ?v=$cur_ver → ?v=$new_ver"

# 4. 刷新 lock（URL 已变，必然重新下载，不走缓存）
nix flake update skemate-latest
echo "完成: skemate $new_ver 已锁定，各机器 rebuild 即生效"
