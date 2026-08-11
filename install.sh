#!/usr/bin/env bash
# ⚠️ 已废弃：本脚本对应旧的「docker run + 挂载 /config」流程，与新架构冲突（用户/配置名均已变更）。
# 新流程见 README.md：docker/ide/ubuntu/Dockerfile 构建镜像（内含 nix 安装）+ 容器内 nix run .#ide。
# 保留仅供参考，勿再执行。
# 一键安装：Ubuntu 容器内执行，自动完成全部配置（幂等，可重复执行）
# 用法：
#   bash /config/install.sh                          # 国内镜像，密码 1234
#   bash /config/install.sh --no-mirror              # 国外：跳过国内镜像
#   bash /config/install.sh --password=mysecret      # 自定义密码
# 也可用环境变量：PASSWORD=mysecret bash /config/install.sh
set -e

USE_MIRROR=1
PASSWORD="${PASSWORD:-1234}"
while [ $# -gt 0 ]; do
  case "$1" in
    --no-mirror) USE_MIRROR=0 ;;
    --password=*) PASSWORD="${1#--password=}" ;;
    --password) PASSWORD="$2"; shift ;;
  esac
  shift
done

echo "==> [1/7] apt 源（$( [ "$USE_MIRROR" = 1 ] && echo 清华镜像 || echo 官方源 )）+ 基础工具"
if [ "$USE_MIRROR" = 1 ] && [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirrors.tuna.tsinghua.edu.cn/ubuntu|g; s|http://security.ubuntu.com/ubuntu|http://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources
fi
apt-get update -y
apt-get install -y curl git vim zsh sudo ca-certificates \
  build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev liblzma-dev

echo "==> [2/7] 安装 Nix（单用户模式，$( [ "$USE_MIRROR" = 1 ] && echo 国内镜像 || echo 官方源 )）"
if ! command -v nix >/dev/null 2>&1; then
  # 先写最小配置：build-users-group 置空（单用户模式没有 nixbld 组，不写会安装失败）
  mkdir -p /etc/nix
  cat > /etc/nix/nix.conf <<'EOF'
experimental-features = nix-command flakes
build-users-group =
EOF
  case "$(uname -m)" in
    aarch64) NIX_ARCH="aarch64-linux" ;;
    x86_64)  NIX_ARCH="x86_64-linux" ;;
    *) echo "    不支持的架构: $(uname -m)"; exit 1 ;;
  esac
  NIX_VERSION="2.35.1"
  if [ "$USE_MIRROR" = 1 ]; then
    NIX_URL="https://mirror.nju.edu.cn/nix/latest/nix-${NIX_VERSION}-${NIX_ARCH}.tar.xz"
  else
    NIX_URL="https://releases.nixos.org/nix/latest/nix-${NIX_VERSION}-${NIX_ARCH}.tar.xz"
  fi
  echo "    下载: $NIX_URL"
  mkdir -p /nix
  curl -L "$NIX_URL" -o /tmp/nix.tar.xz
  cd /tmp && tar -xf nix.tar.xz
  cd "/tmp/nix-${NIX_VERSION}-${NIX_ARCH}" && ./install --no-daemon --no-channel-add --yes
fi
# 单用户 Nix 环境（root profile），供当前 shell 使用
export PATH="/root/.nix-profile/bin:$PATH"
export NIX_SSL_CERT_FILE="${NIX_SSL_CERT_FILE:-/root/.nix-profile/etc/ssl/certs/ca-bundle.crt}"

echo "==> [3/7] 配置 Nix（flakes + $( [ "$USE_MIRROR" = 1 ] && echo 国内镜像 || echo 官方源 )）"
mkdir -p /etc/nix
if [ "$USE_MIRROR" = 1 ]; then
  SUBSTITUTERS="https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/"
else
  SUBSTITUTERS="https://cache.nixos.org/"
fi
cat > /etc/nix/nix.conf <<EOF
experimental-features = nix-command flakes
build-users-group =
substituters = $SUBSTITUTERS
EOF
# 单用户 Nix 环境：写入 /etc/profile.d，所有用户登录自动加载（比改 ~/.profile 更可靠，官方多用户安装器同样用 /etc/profile.d）
# 指向公共 profile：/root/.nix-profile 受 /root 目录 700 权限限制，其他用户进不去
cat > /etc/profile.d/nix.sh <<'EOF'
export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
export NIX_SSL_CERT_FILE="${NIX_SSL_CERT_FILE:-/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt}"
EOF
# zsh 登录不读 /etc/profile，需要单独加载（fan 默认 shell 是 zsh）
mkdir -p /etc/zsh
cat > /etc/zsh/zprofile <<'EOF'
if [ -r /etc/profile.d/nix.sh ]; then
  . /etc/profile.d/nix.sh
fi
EOF

echo "==> [4/7] 创建用户 fan（密码已自定义）"
if ! id fan >/dev/null 2>&1; then
  useradd -m -s /bin/bash fan
fi
echo "fan:$PASSWORD" | chpasswd
# 清理旧版 install.sh 遗留的 .profile 追加（指向 /root 内路径，fan 无法访问，会覆盖公共配置）
sed -i '\|/root/.nix-profile|d' /home/fan/.profile
# 单用户 Nix：fan 需要 store 写权限（nix 环境由 /etc/profile.d/nix.sh 加载）
chown -R fan:fan /nix

# 公共 profile：所有用户可访问（/root/.nix-profile 在 /root 700 目录里，fan 进不去）
if [ -e /root/.nix-profile ] && [ ! -e /nix/var/nix/profiles/default ]; then
  mkdir -p /nix/var/nix/profiles
  cp -a /root/.nix-profile /nix/var/nix/profiles/default
fi
# 证书装进公共 profile（单用户安装器可能跳过 cacert，导致 SSL 报错 77）
CACERT=$(ls -d /nix/store/*-nss-cacert-* 2>/dev/null | head -1)
if [ -n "$CACERT" ] && [ ! -e /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt ]; then
  nix-env -p /nix/var/nix/profiles/default -i "$CACERT"
fi

echo "==> [5/7] 激活 home-manager 配置（首次 5~15 分钟，之后秒级）"
su - fan -c 'nix run /config#homeConfigurations."fan@ide".activationPackage'

echo "==> [6/7] 设置 fan 默认 shell 为 zsh"
chsh -s /usr/bin/zsh fan

echo "==> [7/7] 安装 mise 运行时（node@lts + python@3.12）并验证"
su - fan -c 'mise install' \
  || echo "   警告：mise install 失败（多半是网络），可稍后手动补：su - fan -c \"mise install\""
su - fan -c 'echo "  zsh:    $(which zsh)"; echo "  git:    $(git config user.name) <$(git config user.email)>"; echo "  node:   $(node --version 2>/dev/null || echo 未安装)"; echo "  python: $(python3 --version 2>/dev/null || echo 未安装)"'

echo ""
echo "全部完成！执行 su - fan 进入环境，或直接输入 zsh 体验主题"
