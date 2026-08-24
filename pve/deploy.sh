#!/usr/bin/env bash
# PVE 部署编排（flake packages.<host>：nix run .#<host> [ip]）
# 流程：bootstrap nix → 推 git 凭据 + clone/pull 仓库 → 远程构建 HM + activate → 推送系统配置 → 远程 apply
# 前置：ssh root@<host> 可达（密钥或密码）；mac 侧 ~/.secrets/age-keys.txt 存在（HM secrets 解密必需）
# 占位符 @FILES@ / @APPLY@ 由 pve/deploy.nix 构建时替换
set -euo pipefail
HOST="${1:-@HOST@}"
FILES="@FILES@"
APPLY="@APPLY@"

echo "==> [1/5] bootstrap: 检查/安装 nix on root@$HOST"
ssh root@$HOST 'bash -s' <<'BOOTSTRAP'
set -euo pipefail
# 检查 nix 二进制存在性而非 PATH 命令（非交互 ssh 的 PATH 无 nix，但已装机器不应重跑 installer）
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  echo "nix 未安装，官方 installer 安装中（--daemon，国内网络慢属正常）..."
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi
# 非交互 ssh 不 source /etc/profile.d，后续 [4/5] 远程 nix build 需要 nix 在 PATH（幂等）
ln -sf /nix/var/nix/profiles/default/bin/nix /usr/local/bin/nix
ln -sf /nix/var/nix/profiles/default/bin/nix-store /usr/local/bin/nix-store
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

echo "==> [2/5] 推送 git 凭据 + 拉取仓库 → /tmp/nixcfg（git clone/pull）"
ssh root@$HOST 'mkdir -p /root/.secrets'
scp "$HOME/.git-credentials" root@$HOST:/root/.git-credentials
ssh root@$HOST 'bash -s' <<'REPO'
set -euo pipefail
chmod 600 /root/.git-credentials
command -v git >/dev/null 2>&1 || apt-get install -y git
git config --global credential.helper store
if [ -d /tmp/nixcfg/.git ]; then
  git -C /tmp/nixcfg pull --ff-only
  echo "仓库已存在，pull 完成"
else
  git clone http://git.fan-x.fun/fan/nixcfg.git /tmp/nixcfg
  echo "仓库 clone 完成"
fi
REPO

echo "==> [3/5] 推送 age 私钥（HM secrets 解密必需：ai.env / git-credentials）"
ssh root@$HOST 'mkdir -p /root/.secrets'
scp "$HOME/.secrets/age-keys.txt" root@$HOST:/root/.secrets/age-keys.txt

echo "==> [4/5] 远程构建 HM activation + activate（ohmyzsh / zsh / 工具）"
ssh root@$HOST 'bash -s' <<'HM'
set -euo pipefail
cd /tmp/nixcfg
nix build .#homeConfigurations."fan@@HOST@".activationPackage
USER=root HOME_MANAGER_BACKUP_EXT=backup ./result/activate
HM

echo "==> [5/5] 推送系统配置 + apply 脚本"
ssh root@$HOST 'mkdir -p /tmp/@HOST@-deploy'
scp -r "$FILES"/. root@$HOST:/tmp/@HOST@-deploy/
scp "$APPLY" root@$HOST:/tmp/@HOST@-deploy/apply.sh

echo "==> 远程 apply（系统层：chsh / GRUB / apt 源 / DNS / pve-assist / 去 nag）"
ssh root@$HOST 'bash /tmp/@HOST@-deploy/apply.sh'
