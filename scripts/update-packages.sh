#!/usr/bin/env bash
# 更新 packages/ 下自建包的 pin（版本 + hash）：codex-bin / rustdesk-bin / kasmvnc
#
# 为什么需要它：这三个包直接钉 GitHub release 资产的 version 与 sha256（免源码编译，
#   见 packages/*.nix 头注释）。`nix flake update` 只动 flake.lock，碰不到它们 ——
#   不加本脚本，包会一直停在打包时的版本。
#
# 用法：
#   scripts/update-packages.sh            # 检查并就地更新有新版的文件
#   scripts/update-packages.sh --check    # 只报告，有新版则 exit 1（可用于门禁）
#   scripts/update-packages.sh codex-bin  # 只更新指定包
#
# 之后照常 `git diff` 复核、提交，再让容器/机器激活。
# 网络：hash 计算走上游官方 URL 直连（ghfast 镜像可能滞后于 GitHub，不能用来算 hash）；
#   资产本体由 nix 构建期从 .nix 里声明的镜像优先拉取，与此处无关。
set -euo pipefail

cd "$(dirname "$0")/.."

CHECK_ONLY=0
ONLY=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    -h | --help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*) echo "未知选项: $arg" >&2; exit 2 ;;
    *) ONLY+=("$arg") ;;
  esac
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# GitHub 加速前缀（与 tools/config.nix 的 githubProxy 同值；脚本在 nix 之外，无法 import，故手写）
GH_PROXY="https://ghfast.top/"

# 下载并算 SRI hash。必须先试镜像：本机直连 GitHub release 实测 0 字节（完全不通），
# 只用直连会永久挂住。镜像只是代理转发，字节相同，hash 与官方一致。
fetch_sri() {
  local url=$1 name=$2 hex
  if ! curl -fsSL --retry 3 --max-time 1800 -o "$tmpdir/$name" "$GH_PROXY$url"; then
    echo "镜像下载失败，改试直连: $url" >&2
    curl -fsSL --retry 2 --max-time 1800 -o "$tmpdir/$name" "$url"
  fi
  hex=$(shasum -a 256 "$tmpdir/$name" | cut -d' ' -f1)
  nix hash convert --hash-algo sha256 --to sri "$hex"
}

# 取 GitHub 最新 release 的 tag（去前导 v）；API 直连可能不通，同样走镜像
latest_tag() {
  local repo=$1 body
  body=$(curl -fsSL --retry 3 --max-time 90 "${GH_PROXY}https://api.github.com/repos/$repo/releases/latest" 2>/dev/null) \
    || body=$(curl -fsSL --retry 2 --max-time 90 "https://api.github.com/repos/$repo/releases/latest")
  printf '%s' "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))'
}

changed=0
updated=()

# ── codex-bin ────────────────────────────────────────────────────────────────
update_codex() {
  local file=packages/codex-bin.nix cur tag base
  cur=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$file")
  tag=$(latest_tag openai/codex | sed 's/^rust-v//')
  if [ "$cur" = "$tag" ]; then
    echo "codex-bin    已是最新 ($cur)"
    return 0
  fi
  echo "codex-bin    $cur -> $tag"
  [ "$CHECK_ONLY" = 1 ] && { changed=1; return 0; }

  base="https://github.com/openai/codex/releases/download/rust-v$tag"
  local aarch x86
  aarch=$(fetch_sri "$base/codex-package-aarch64-unknown-linux-musl.tar.gz" codex-aarch64.tgz)
  x86=$(fetch_sri "$base/codex-package-x86_64-unknown-linux-musl.tar.gz" codex-x86_64.tgz)

  sed -i.bak \
    -e "s|^  version = \".*\";$|  version = \"$tag\";|" \
    -e "s|hash = \"sha256-U6nOC5S+snpj/esvdwTZUZnheziYqjO2BGGhqTrA2Is=\";|hash = \"$aarch\";|" \
    -e "s|hash = \"sha256-pnb1ciquDYbL43ZDMvCOqx/didwKMAs61P+/SGEfo+M=\";|hash = \"$x86\";|" \
    "$file"
  # hash 若在别处已变（上次更新留下的值），按 target 行就近替换，兜住上面的字面量匹配失效
  python3 - "$file" "$aarch" "$x86" <<'PY'
import re, sys
path, aarch, x86 = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
def fix(src, target, newhash):
    pat = re.compile(r'(target = "' + re.escape(target) + r'";\n\s*hash = ")[^"]+(";)')
    return pat.sub(lambda m: m.group(1) + newhash + m.group(2), src)
src = fix(src, "aarch64-unknown-linux-musl", aarch)
src = fix(src, "x86_64-unknown-linux-musl", x86)
open(path, "w").write(src)
PY
  rm -f "$file.bak"
  updated+=(codex-bin)
}

# ── rustdesk-bin ─────────────────────────────────────────────────────────────
update_rustdesk() {
  local file=packages/rustdesk-bin.nix cur tag base hash
  cur=$(sed -n 's/^    version = "\(.*\)";$/\1/p' "$file" | head -1)
  tag=$(latest_tag rustdesk/rustdesk)
  if [ "$cur" = "$tag" ]; then
    echo "rustdesk-bin 已是最新 ($cur)"
    return 0
  fi
  echo "rustdesk-bin $cur -> $tag"
  [ "$CHECK_ONLY" = 1 ] && { changed=1; return 0; }

  base="https://github.com/rustdesk/rustdesk/releases/download/$tag"
  hash=$(fetch_sri "$base/rustdesk-$tag-x86_64.deb" rustdesk.deb)

  # 两处 version（fetchurl 段与 stdenv.mkDerivation 段）+ 两处 URL + 一处 sha256
  sed -i.bak \
    -e "s|^    version = \".*\";$|    version = \"$tag\";|" \
    -e "s|^  version = \".*\";$|  version = \"$tag\";|" \
    -e "s|releases/download/[^/]*/rustdesk-[^/]*\.deb|releases/download/$tag/rustdesk-$tag-x86_64.deb|g" \
    -e "s|sha256 = \"sha256-[^\"]*\";|sha256 = \"$hash\";|" \
    "$file"
  rm -f "$file.bak"
  updated+=(rustdesk-bin)
}

# ── kasmvnc ──────────────────────────────────────────────────────────────────
update_kasmvnc() {
  local file=packages/kasmvnc.nix cur tag base amd arm
  cur=$(sed -n 's/^  version = "\(.*\)";$/\1/p' "$file")
  tag=$(latest_tag kasmtech/KasmVNC)
  if [ "$cur" = "$tag" ]; then
    echo "kasmvnc      已是最新 ($cur)"
    return 0
  fi
  echo "kasmvnc      $cur -> $tag"
  [ "$CHECK_ONLY" = 1 ] && { changed=1; return 0; }

  base="https://github.com/kasmtech/KasmVNC/releases/download/v$tag"
  amd=$(fetch_sri "$base/kasmvncserver_noble_${tag}_amd64.deb" kasm-amd64.deb)
  arm=$(fetch_sri "$base/kasmvncserver_noble_${tag}_arm64.deb" kasm-arm64.deb)

  python3 - "$file" "$tag" "$amd" "$arm" <<'PY'
import re, sys
path, ver, amd, arm = sys.argv[1:5]
src = open(path).read()
src = re.sub(r'^  version = ".*";$', f'  version = "{ver}";', src, count=1, flags=re.M)
src = re.sub(r'(  debSha256 =\n    \{\n      amd64 = ")[^"]+(";)',
             lambda m: m.group(1) + amd + m.group(2), src, count=1)
src = re.sub(r'(      arm64 = ")[^"]+(";)',
             lambda m: m.group(1) + arm + m.group(2), src, count=1)
open(path, "w").write(src)
PY
  updated+=(kasmvnc)
}

wanted() {
  [ ${#ONLY[@]} -eq 0 ] && return 0
  local p
  for p in "${ONLY[@]}"; do [ "$p" = "$1" ] && return 0; done
  return 1
}

wanted codex-bin && update_codex
wanted rustdesk-bin && update_rustdesk
wanted kasmvnc && update_kasmvnc

echo
if [ "$CHECK_ONLY" = 1 ]; then
  if [ "$changed" = 1 ]; then
    echo "有包可更新（跑 scripts/update-packages.sh 更新）" >&2
    exit 1
  fi
  echo "全部已是最新"
elif [ ${#updated[@]} -gt 0 ]; then
  echo "已更新: ${updated[*]}"
  echo "下一步: git diff 复核 → 提交 → 各机激活"
else
  echo "无改动"
fi
