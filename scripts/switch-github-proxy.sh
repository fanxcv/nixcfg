#!/usr/bin/env bash
# 切换 GitHub 加速前缀（集中管理入口）
# 用法：./scripts/switch-github-proxy.sh <新域名，如 ghfast.top 或 gh-proxy.com>
# 效果：替换三处（flake.nix inputs url、flake.lock、tools/github-proxy.nix），然后重新锁定
# 注意：只传域名（不含协议）；域名为空或 "none" 表示直连 GitHub（不套前缀）
set -euo pipefail
cd "$(dirname "$0")/.."

OLD_DOMAINS="ghfast.top gh-proxy.com ghproxy.net gh.zwy.one"
NEW_DOMAIN="${1:-}"

if [[ -z "$NEW_DOMAIN" || "$NEW_DOMAIN" == "none" ]]; then
  echo "==> 切换到直连模式"
  for d in $OLD_DOMAINS; do
    sed -i '' "s#git+https://${d}/https://github.com#git+https://github.com#g" flake.nix flake.lock
    sed -i '' "s#https://${d}/https://github.com#https://github.com#g" flake.nix flake.lock
  done
  echo '"# 直连（国外机器）' > /dev/null
  printf '""\n' > tools/github-proxy.nix
else
  echo "==> 切换到加速域名: $NEW_DOMAIN"
  for d in $OLD_DOMAINS; do
    sed -i '' "s#git+https://${d}/https://github.com#git+https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
    sed -i '' "s#https://${d}/https://github.com#https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
  done
  sed -i '' "s#git+https://github.com#git+https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
  sed -i '' "s#https://github.com#https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
  printf '"https://%s/"\n' "$NEW_DOMAIN" > tools/github-proxy.nix
fi

echo "==> 重新锁定 flake.lock（保持现有 rev，仅更新 url）"
nix flake lock
echo "==> 完成。验证：grep -c '${NEW_DOMAIN:-直连}' flake.lock"
