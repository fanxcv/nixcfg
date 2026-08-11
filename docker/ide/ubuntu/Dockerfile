FROM ubuntu:24.04

# 宗旨：能 nix 就 nix，实在不行的才留在 Dockerfile（apt）
# 系统层只保留"必须系统级"的部分：
#   systemd          → PID1（entrypoint exec /usr/sbin/init），容器基础设施
#   openssh-server   → ssh.service 与 systemd 集成（sshd_config 加固由 nix activation 做）
#   zsh              → /etc/passwd 登录 shell（nix 的 zsh 在 store 路径不稳定，不适合做登录 shell）
#   git/curl         → 构建期装 nix + 首次激活必需（clone nixcfg），switch 后由 nix 接管
#   tzdata/ca-certificates → /usr/share/zoneinfo、/etc/ssl/certs 系统基础路径
# 其余软件包全部 nix 管理：net-tools/inetutils→_nixos_/base.nix，vim/tmux/make→nix，jq→mise

# 配置APT源并安装系统级包
# 关键：arm64/非 amd64 架构官方走 ports.ubuntu.com，镜像对应 ubuntu-ports 目录（主源只有 amd64）
# 统一 http + USTC：ca-certificates 尚未安装（https 握手失败）；security 套件镜像也同步
ARG TARGETARCH
RUN arch_dir="ubuntu"; [ "$TARGETARCH" = "arm64" ] && arch_dir="ubuntu-ports"; \
    cat << EOF > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://mirrors.ustc.edu.cn/${arch_dir}
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

RUN apt update -y \
    && echo -e "Asia\nShanghai" | apt install -y tzdata ca-certificates systemd openssh-server git curl zsh xz-utils \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 安装 nix（单用户模式，全部走清华镜像：install 脚本 + tarball + binary cache）
# 注意：root 下安装脚本不会自动创建 /nix（会尝试 sudo），需先手动建好；
#       2.35 起 root 跑 nix 按多用户语义解析配置（build-users-group=nixbld），需先建组；
#       --tarball-url-prefix 不被真实安装器接受（打印 usage 静默退出），省略（包装脚本默认即清华 URL）
RUN groupadd -r nixbld && useradd -g nixbld nixbld \
    && mkdir -m 0755 /nix \
    && mkdir -p /etc/nix \
    && printf 'build-users-group =\n' > /etc/nix/nix.conf \
    && curl -fsL https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install -o /tmp/nix-install.sh \
    && sh /tmp/nix-install.sh --no-daemon --no-channel-add --yes \
    && rm -f /tmp/nix-install.sh

# nix 配置：国内 binary cache + flake 支持（单用户模式配置文件在 ~/.config/nix/nix.conf）
# 与 flake.nix 的 nixConfig 一致，覆盖非 flake 命令场景
RUN mkdir -p /root/.config/nix \
    && printf 'substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/\nexperimental-features = nix-command flakes\n' > /root/.config/nix/nix.conf

COPY entrypoint.sh /usr/local/bin/

RUN chmod a+x /usr/local/bin/entrypoint.sh \
    && systemctl enable ssh \
    && chsh -s /bin/zsh

ENTRYPOINT ["entrypoint.sh"]
CMD []
