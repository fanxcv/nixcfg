#!/bin/sh
# ide 容器配置自动部署（pull 轮询模型；现成系统级部署器只认 nixos/darwin 配置输出且需系统级接入）
# 由 ide-auto-deploy.nix 激活时安装到 /usr/local/bin/（sed 替换 @hostName@）
# 逻辑：/root/nixcfg（compose bind mount 宿主工作树，不 clone）fetch origin/main，
#   与 $STATE/last 记录的已部署 commit 比对；不一致则强切 main 到 origin/main 后 nix run .#<hostName>
# 与分支无关：容器内无论停在哪个分支（test 等）都以 origin/main 为准强切，
#   避免长期停在测试分支导致自动部署失效（本仓库是宿主工作树，分支由本脚本接管）
# 状态：$STATE/last 记录上次成功部署的 origin/main commit；容器重建后清空 → 首次轮询自动部署
# 代理：ide-si 的 all_proxy 由 sysenv.nix 写 /etc/environment.d/zz-ide-proxy.conf，systemd 服务启动自动注入，无需重复处理
# 失败重试：fetch 失败 / 激活失败均不更新 last，下次轮询自动重试
set -eu
export GIT_TERMINAL_PROMPT=0
REPO=/root/nixcfg
STATE=/var/lib/ide-auto-deploy
BRANCH=main
mkdir -p "$STATE"
cd "$REPO" || { echo "[ide-auto-deploy] $REPO 不存在"; exit 0; }

# 远端 main 最新提交（网络失败保留现状，下轮重试）
if ! git fetch -q origin "$BRANCH" 2>/dev/null; then
  echo "[ide-auto-deploy] fetch origin/$BRANCH 失败（网络？），跳过本轮"
  exit 0
fi
REMOTE=$(git rev-parse "refs/remotes/origin/$BRANCH" 2>/dev/null || echo "")
[ -n "$REMOTE" ] || { echo "[ide-auto-deploy] 无法解析 origin/$BRANCH"; exit 0; }

LAST=$(cat "$STATE/last" 2>/dev/null || echo "")
if [ "$REMOTE" = "$LAST" ]; then
  exit 0
fi

echo "===> [ide-auto-deploy] origin/$BRANCH 变更 ${LAST:+$LAST → }${REMOTE} ，强切 $BRANCH 并激活 .#@hostName@"

# 宿主工作树可能有未提交改动：先 stash（含未跟踪）保命，失败则放弃本轮，不丢数据
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  if git stash push -q -u -m "ide-auto-deploy $(date +%Y%m%d-%H%M%S)" 2>/dev/null; then
    echo "[ide-auto-deploy] 未提交改动已 stash（git stash list 找回）"
  else
    echo "[ide-auto-deploy] 工作树有未提交改动且 stash 失败，跳过本轮"
    exit 0
  fi
fi

# 强切：-B 建或重置分支，-f 忽略残留差异
if ! git checkout -q -f -B "$BRANCH" "refs/remotes/origin/$BRANCH" 2>/dev/null; then
  echo "[ide-auto-deploy] 强切 $BRANCH 失败，跳过本轮"
  exit 0
fi

# 部分 derivation 构建期联网下载（__noChroot）；nix 禁止 __noChroot 与 sandbox 并存 → 本次构建关沙箱
# --accept-flake-config：接受 flake.nix 的 nixConfig（CERNET 镜像），保存到 trusted-settings.json 后永久生效
if nix run --accept-flake-config --option sandbox false .#@hostName@; then
  echo "$REMOTE" > "$STATE/last"
  echo "===> [ide-auto-deploy] 激活成功（${REMOTE}）"
else
  echo "===> [ide-auto-deploy] 激活失败（下次轮询重试）"
fi
