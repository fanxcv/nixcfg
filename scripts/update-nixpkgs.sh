#!/usr/bin/env bash
# 升级 nixpkgs 到国内镜像已同步的最新版（构建命中 USTC/TUNA 缓存）
# 两个 channel：nixos-26.05（Linux 机器）+ nixpkgs-26.05-darwin（mac，配套 nix-darwin-26.05）
# 用法：./scripts/update-nixpkgs.sh [镜像]（默认 USTC，可换 TUNA：https://mirrors.tuna.tsinghua.edu.cn/nix-channels）
set -euo pipefail
cd "$(dirname "$0")/.."

mirror="${1:-https://mirrors.ustc.edu.cn/nix-channels}"
echo "查询 $mirror 同步版本..."

fetch_rev() {
  curl -fsSL --max-time 300 "$mirror/$1/nixexprs.tar.xz" \
    | tar -xJ --to-stdout '*/.git-revision'
}

update_flake() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
ref, rev = sys.argv[1], sys.argv[2]
lines = open('flake.nix').read().split('\n')
pat = re.compile(r'^(.*ref=' + re.escape(ref) + r'&)rev=[0-9a-f]{40}(&shallow=1.*)$')
found = False
for i, line in enumerate(lines):
    m = pat.match(line)
    if m:
        lines[i] = m.group(1) + 'rev=' + rev + m.group(2)
        found = True
if not found:
    raise SystemExit(f'flake.nix 未找到 ref={ref} 的行')
open('flake.nix', 'w').write('\n'.join(lines))
print(f'  更新 ref={ref} → rev={rev[:12]}')
PYEOF
}

for ref in nixos-26.05 nixpkgs-26.05-darwin; do
  cur=$(grep -oE "ref=${ref}&rev=[0-9a-f]{40}" flake.nix | head -1 | sed "s/ref=${ref}&rev=//" || true)
  echo "== $ref"
  if [ -n "$cur" ]; then
    echo "  当前 rev: ${cur:0:12}"
    rev=$(fetch_rev "$ref")
    if [ "$cur" = "$rev" ]; then
      echo "  已是最新（与镜像同步点一致）"
      continue
    fi
    update_flake "$ref" "$rev"
  fi
done

nix flake lock
echo "完成。构建将命中镜像缓存；如遇 gh-proxy 限流失败可稍后重试。"
