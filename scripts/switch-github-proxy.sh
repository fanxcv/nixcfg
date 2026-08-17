#!/usr/bin/env bash
# 切换 GitHub 加速前缀（集中管理入口）
# 用法：./scripts/switch-github-proxy.sh <新域名，如 ghfast.top 或 gh-proxy.com>
# 效果：读集中配置 tools/config.nix → 替换 flake.nix inputs url + flake.lock，回写 config.nix 的 githubProxy，然后重新锁定
# 注意：只传域名（不含协议）；域名为空或 "none" 表示直连 GitHub（不套前缀）
set -euo pipefail
cd "$(dirname "$0")/.."

OLD_DOMAINS="ghfast.top gh-proxy.com ghproxy.net gh.zwy.one"
NEW_DOMAIN="${1:-}"
CONFIG="tools/config.nix"

if [[ -z "$NEW_DOMAIN" || "$NEW_DOMAIN" == "none" ]]; then
  echo "==> 切换到直连模式"
  for d in $OLD_DOMAINS; do
    sed -i '' "s#git+https://${d}/https://github.com#git+https://github.com#g" flake.nix flake.lock
    sed -i '' "s#https://${d}/https://github.com#https://github.com#g" flake.nix flake.lock
  done
  sed -i '' 's#^  githubProxy = "https://[^"]*/";#  githubProxy = "";                   # 直连 GitHub（国外机器）#' "$CONFIG"
else
  echo "==> 切换到加速域名: $NEW_DOMAIN"
  for d in $OLD_DOMAINS; do
    sed -i '' "s#git+https://${d}/https://github.com#git+https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
    sed -i '' "s#https://${d}/https://github.com#https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
  done
  sed -i '' "s#git+https://github.com#git+https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
  sed -i '' "s#https://github.com#https://${NEW_DOMAIN}/https://github.com#g" flake.nix flake.lock
  sed -i '' 's#^  githubProxy = "";#  githubProxy = "https://'"$NEW_DOMAIN"'/";#' "$CONFIG"
  sed -i '' 's#^  githubProxy = "https://[^"]*/";#  githubProxy = "https://'"$NEW_DOMAIN"'/";#' "$CONFIG"
fi

echo "==> 重新锁定 flake.lock（保持现有 rev，仅更新 url）"
nix flake lock
echo "==> 完成。验证：grep -c '${NEW_DOMAIN:-直连}' flake.lock；集中配置见 $CONFIG"