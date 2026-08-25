#!/usr/bin/env bash
# 加密 secrets/source/ 下的明文文件 -> secrets/<同名>.age
# 接收者：keys.nix 中的全部 age 公钥（新增机器时往 keys.nix 加公钥即可，无需改脚本）
# 用法：./encrypt.sh [--force]   （默认跳过已存在的 .age，--force 覆盖）
set -euo pipefail
cd "$(dirname "$0")"

command -v age >/dev/null || { echo "错误：未找到 age（nix shell nixpkgs#age）" >&2; exit 1; }
grep -qE 'age1[a-z0-9]{50,}' keys.nix || { echo "错误：keys.nix 中没有 age 公钥" >&2; exit 1; }

count=0
# 只加密私密文件：*.pub 公钥明文直接入库（secrets/hosts/<机>/），不入 source、不加密
while IFS= read -r f; do
  # 保持 source/ 下的子目录结构（如 hosts/nix-pve/）
  rel="${f#source/}"
  out="${rel}.age"
  mkdir -p "$(dirname "$out")"
  if [[ -f "$out" && "${1:-}" != "--force" ]]; then
    echo "跳过（已存在，用 --force 覆盖）: $out"
    continue
  fi
  age -e -R <(grep -oE 'age1[a-z0-9]{50,}' keys.nix | sort -u) -o "$out" "$f"
  echo "已加密: $f -> $out"
  count=$((count + 1))
done < <(find source -type f ! -name '*.pub' | sort)

echo "完成：新加密 $count 个文件"
