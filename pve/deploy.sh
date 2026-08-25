#!/usr/bin/env bash
# PVE 部署编排（flake packages.<host>：nix run .#<host> [ip]）
# 流程：bootstrap nix → 推 git 凭据 + clone/pull 仓库 → 远程构建 HM + activate → 推送系统配置 → 远程 apply
# 前置：ssh root@<host> 可达（密钥或密码）；mac 侧 ~/.secrets/age-keys.txt 存在（HM secrets 解密必需）
# 占位符 @FILES@ / @APPLY@ 由 pve/deploy.nix 构建时替换
set -euo pipefail
# --self：服务器本地自部署模式（跳过 mac 依赖段：凭据/私钥推送；git 用 /root/nixcfg 持久 clone）
SELF=0
if [ "${1:-}" = "--self" ]; then
  SELF=1
  HOST="127.0.0.1"
  shift
else
  HOST="${1:-@HOST@}"
fi
FILES="@FILES@"
APPLY="@APPLY@"

if [ "$SELF" = "1" ]; then
  echo "==> 自部署模式（目标=本机；凭据/私钥已在 /root/.secrets）"
fi

echo "==> [1/4] bootstrap: 检查/安装 nix on root@$HOST"
ssh root@$HOST 'bash -s' <<'BOOTSTRAP'
set -euo pipefail
# 检查 nix 二进制存在性而非 PATH 命令（非交互 ssh 的 PATH 无 nix，但已装机器不应重跑 installer）
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  echo "nix 未安装，官方 installer 安装中（--daemon，国内网络慢属正常）..."
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi
# 非交互 ssh 不 source /etc/profile.d，后续 [4/4] 远程 nix build + activate 需要 nix 全家在 PATH（幂等）
ln -sf /nix/var/nix/profiles/default/bin/nix /usr/local/bin/nix
ln -sf /nix/var/nix/profiles/default/bin/nix-store /usr/local/bin/nix-store
ln -sf /nix/var/nix/profiles/default/bin/nix-build /usr/local/bin/nix-build
# 镜像 substituters（幂等；与仓库 flake.nix nixConfig 一致）
if [ ! -f /etc/nix/nix.conf ] || ! grep -q "mirrors.ustc.edu.cn" /etc/nix/nix.conf; then
  mkdir -p /etc/nix
  cat > /etc/nix/nix.conf <<'NIXCONF'
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
experimental-features = nix-command flakes
NIXCONF
fi
# claude-code 等 derivation 带 __noChroot（构建时需网络/特权），relaxed 允许其非沙箱构建
if ! grep -q "^sandbox" /etc/nix/nix.conf; then
  echo 'sandbox = relaxed' >> /etc/nix/nix.conf
fi
BOOTSTRAP

echo "==> [2/4] git 凭据 + 拉取仓库 → /root/nixcfg（git clone/pull）"
if [ "$SELF" = "0" ]; then
  ssh root@$HOST 'mkdir -p /root/.secrets'
  scp "$HOME/.git-credentials" root@$HOST:/root/.git-credentials
fi
ssh root@$HOST 'bash -s' <<'REPO'
set -euo pipefail
chmod 600 /root/.git-credentials 2>/dev/null || true
command -v git >/dev/null 2>&1 || apt-get install -y git
git config --global credential.helper store
if [ -d /root/nixcfg/.git ]; then
  git -C /root/nixcfg pull --ff-only
  echo "仓库已存在，pull 完成"
else
  git clone http://git.fan-x.fun/fan/nixcfg.git /root/nixcfg
  echo "仓库 clone 完成（持久化 /root/nixcfg，重启不丢）"
fi
REPO

echo "==> [3/4] age 私钥（HM secrets 解密必需；自部署模式跳过——已在本机）"
if [ "$SELF" = "0" ]; then
  ssh root@$HOST 'mkdir -p /root/.secrets'
  scp "$HOME/.secrets/age-keys.txt" root@$HOST:/root/.secrets/age-keys.txt
fi

@TS_PUSH@

@LUCKY_PUSH@

echo "==> [4/4] 远程构建 HM activation + activate（ohmyzsh / zsh / 工具）"
ssh root@$HOST 'bash -s' <<'HM'
set -euo pipefail
# 非交互 ssh 的 PATH 不含 nix（/etc/profile.d 不加载），显式补全
# （BOOTSTRAP 已软链 /usr/local/bin，此处双保险）
export PATH="/usr/local/bin:/nix/var/nix/profiles/default/bin:$PATH"
cd /root/nixcfg
nix build .#homeConfigurations."fan@@HOST@".activationPackage
USER=root HOME_MANAGER_BACKUP_EXT=backup ./result/activate
HM

# 推送系统配置 + apply 脚本 + self-deploy 入口（自部署后续由 /root/self-deploy.sh 承担）
ssh root@$HOST 'mkdir -p /tmp/@HOST@-deploy'
scp -r "$FILES"/. root@$HOST:/tmp/@HOST@-deploy/
scp "$APPLY" root@$HOST:/tmp/@HOST@-deploy/apply.sh
ssh root@$HOST "cat > /root/self-deploy.sh" <<'SELFDEPLOY'
@SELF_DEPLOY@
SELFDEPLOY
ssh root@$HOST 'chmod +x /root/self-deploy.sh && echo self-deploy 入口已就位（/root/self-deploy.sh）'

echo "==> 远程 apply（系统层：chsh / GRUB / apt 源 / DNS / pve-assist / 去 nag）"
ssh root@$HOST 'bash /tmp/@HOST@-deploy/apply.sh'
