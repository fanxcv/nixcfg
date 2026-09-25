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
# 统一 http + CERNET：ca-certificates 尚未安装（https 握手失败）；security 套件镜像也同步
ARG TARGETARCH
RUN arch_dir="ubuntu"; [ "$TARGETARCH" = "arm64" ] && arch_dir="ubuntu-ports"; \
    cat << EOF > /etc/apt/sources.list.d/ubuntu.sources
Types: deb
URIs: http://mirrors.cernet.edu.cn/${arch_dir}
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

RUN apt update -y \
    && echo -e "Asia\nShanghai" | apt install -y tzdata ca-certificates systemd openssh-server git curl zsh xz-utils sudo \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# fan 用户 + NOPASSWD sudo 兜底：桌面会话（KasmVNC，见各机器 kasmvnc.nix 的 sessionHome=/home/fan）
#   以 fan 运行；镜像层先建好用户，避免 HM 激活（_container_/session-user.nix）之前桌面/命令无 fan 可用。
#   与激活脚本幂等共存（脚本以 id -u 判存、重复写 sudoers 无副作用）；/home/fan 属主移交由脚本负责。
RUN useradd -m -u 1000 -s /bin/bash fan \
    && usermod -aG sudo fan \
    && printf 'fan ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/fan \
    && chmod 0440 /etc/sudoers.d/fan \
    && visudo -cf /etc/sudoers.d/fan

# 安装 nix（单用户模式，全部走 CERNET 镜像：install 脚本 + tarball + binary cache）
# 注意：root 下安装脚本不会自动创建 /nix（会尝试 sudo），需先手动建好；
#       2.35 起 root 跑 nix 按多用户语义解析配置（build-users-group=nixbld），需先建组；
#       --tarball-url-prefix 不被真实安装器接受（打印 usage 静默退出），省略（CERNET 包装脚本默认即 NJU tarball 源）
# nix.conf 必须写 /etc/nix/nix.conf（系统级）：compose 挂载 ./kde-config → /root/.config 会遮蔽
#   镜像内 /root/.config/nix/nix.conf（重建后 nix-command disabled 报错的根因）；/etc/nix 不在挂载路径
RUN groupadd -r nixbld && useradd -g nixbld nixbld \
    && mkdir -m 0755 /nix \
    && mkdir -p /etc/nix \
    && printf 'build-users-group =\nsubstituters = https://mirrors.cernet.edu.cn/nix-channels/store https://cache.nixos.org/\nextra-substituters = https://cache.numtide.com https://nix-community.cachix.org\nextra-trusted-public-keys = cache.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=\nexperimental-features = nix-command flakes\nauto-optimise-store = true\n' > /etc/nix/nix.conf \
    && curl -fsL https://mirrors.cernet.edu.cn/nix/latest/install -o /tmp/nix-install.sh \
    && sh /tmp/nix-install.sh --no-daemon --no-channel-add --yes \
    && rm -f /tmp/nix-install.sh

# nix 配置已并入上方 /etc/nix/nix.conf（国内 binary cache + flake 支持，与 tools/config.nix 及
# flake.nix nixConfig 手写对齐，Docker build 解析阶段无法导入 Nix attrset）；不再写
# /root/.config/nix/nix.conf（被 compose kde-config 挂载遮蔽）
# nix 可执行性（构建期镜像内无 HM 管理的 ~/.zshenv/~/.zshrc）：
#   1. ENV PATH 追加 nix bin：docker exec ide nix / sh -c 等非 shell 场景可用
#   2. /etc/zsh/zshenv source nix.sh：系统级全局配置（root 的 zsh 也会读），
#      ssh 会话/远程命令在 HM 激活前即可用 nix；激活后 ~/.zshenv 由 HM 接管
#      （home/fan/_common_/shells.nix 的 envExtra/initContent，含同款 source），
#      不写用户文件避免 HM clobber 冲突
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
RUN mkdir -p /etc/zsh \
    && printf '. /nix/var/nix/profiles/default/etc/profile.d/nix.sh\n' > /etc/zsh/zshenv

COPY entrypoint.sh /usr/local/bin/

RUN chmod a+x /usr/local/bin/entrypoint.sh \
    && systemctl enable ssh \
    && chsh -s /bin/zsh \
    && mkdir -p /etc/systemd/journald.conf.d \
    && printf '[Journal]\nSystemMaxUse=100M\nSystemMaxFileSize=10M\nMaxRetentionSec=1week\n' > /etc/systemd/journald.conf.d/zz-limits.conf

ENTRYPOINT ["entrypoint.sh"]
CMD []
