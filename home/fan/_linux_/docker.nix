# docker + docker-compose（对应 alpine-init.sh 的 install_docker()）
# 本层被 _nixos_/_ubuntu_/_pve_/_container_ 导入 -> Linux 生效（mac 不装）
# nix 侧统一用官方包，不区分发行版源：
#   pkgs.docker          → 脚本的 apk docker / apt docker-ce（client + daemon）
#   pkgs.docker-compose  → 脚本手动下载的 release 二进制（v2）
#   pkgs.docker-buildx   → 脚本 Ubuntu 分支的 docker-buildx-plugin（nix 侧统一提供）
# 自启 + dc 软链 + network fan 由 home.activation 完成（需 root 或 sudo NOPASSWD）
# 不装的两类：
#   isContainer（ide 容器）→ 容器里 docker daemon 起不来，连检测都不跑
#   NixOS 真机（platform=nixos）→ 运行时统一 podman，见 hosts/_nixos_/services/podman.nix：
#     其 dockerCompat 提供 docker 命令（→ podman）与 /run/docker.sock，再装 docker 包只会两份 daemon 互扰
# 另：机器层可显式设 softwares.docker.enable = false 保留外部 docker；当前无机器如此——
#   ficc-test-pve 与 hc-test-pve 均 adoptSystem = true 由 nix 接管（/var/lib/docker 原地复用，容器随 restart 策略回来）

{ 
  pkgs,
  lib,
  tools,
  config,
  isContainer ? false,
  useChinaMirror ? true,
  platform ? "linux",
  ...
}:
let
  cfg = config.softwares.docker;
  enabled = cfg.enable;
in
{
  options.softwares.docker.enable = lib.mkOption {
    type = lib.types.bool;
    default = !isContainer && platform != "nixos";
    description = "是否安装并接管 docker（podman 机器或需保留外部 docker 的机器设 false）";
  };

  # 接管系统发行版的 docker：Ubuntu 上 apt docker-ce 的 daemon 换成 nix 渲染的 unit。
  # 数据不迁：/var/lib/docker 原地复用（容器/镜像/网络/卷全在里面），只换 daemon 二进制。
  # 回退：装回 docker-ce + 停用本模块单元，容器随 restart 策略自动回来。
  options.softwares.docker.adoptSystem = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "接管前系统自带 docker（apt docker-ce）：停用并卸载其单元/包，daemon 改由 nix 单元承担";
  };

  # 引入 options 后，配置项必须显式包在 config 内
  config = {
  home.packages = lib.mkIf enabled (
    with pkgs;
    [
      docker
      docker-compose
      docker-buildx
    ]
  );

  home.activation.setupDocker = lib.mkIf enabled (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      setup_docker() {
        SUDO=""
        [ "$(id -u)" = 0 ] || SUDO="sudo"

        # 1) 接管系统自带 docker（apt docker-ce）：停用其单元 + 卸包，daemon 改由 nix 单元承担。
        #    nix 的 dockerd 自带 containerd/runc/tini（moby 闭包内），故 apt containerd.io 一并卸掉。
        #    /var/lib/docker 不动 —— 容器/网络/卷原样保留，靠 restart 策略自动拉起。
        #    幂等：已接管（nix 单元在位且 apt 包已卸）就只确保服务在跑，不再重写单元/重启 daemon，
        #    否则每次部署都会停起 docker 把全部容器弹一遍。
        if [ "${if cfg.adoptSystem then "true" else "false"}" = true ] \
           && grep -q 'nix-managed' /etc/systemd/system/docker.service 2>/dev/null \
           && ! dpkg -l docker-ce 2>/dev/null | grep -q '^ii'; then
          ''${SUDO} systemctl enable --now docker.socket docker > /dev/null 2>&1 \
            || echo "警告: nix docker 服务启动失败（journalctl -u docker 查因）"
          echo "===> docker daemon: $( ''${SUDO} ${pkgs.docker}/bin/docker version --format '{{.Server.Version}}' 2>/dev/null || echo 未就绪 )（已接管，未重启）"
        elif [ "${if cfg.adoptSystem then "true" else "false"}" = true ] && command -v systemctl > /dev/null 2>&1; then
          ''${SUDO} systemctl disable --now docker.socket docker > /dev/null 2>&1 \
            || true   # 幂等：未装 apt docker 时属预期失败
          ''${SUDO} getent group docker > /dev/null 2>&1 || ''${SUDO} groupadd -r docker
          ''${SUDO} mkdir -p /etc/docker /etc/systemd/system

          # socket 路径必须仍是 /var/run/docker.sock：容器内 docker 客户端（ssl-sync/act-runner）认这个路径
          ''${SUDO} tee /etc/systemd/system/docker.socket > /dev/null <<'EOF'
[Unit]
Description=Docker Socket for the API (nix-managed)

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF
          ''${SUDO} tee /etc/systemd/system/docker.service > /dev/null <<'EOF'
[Unit]
Description=Docker Application Container Engine (nix-managed)
Documentation=https://docs.docker.com
After=network-online.target
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
ExecStart=__DOCKERD__ -H fd://
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=2
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF
          ''${SUDO} sed -i "s|__DOCKERD__|${pkgs.docker}/bin/dockerd|" /etc/systemd/system/docker.service

          # 卸 apt 包（只卸二进制与 /usr/lib 单元，不碰 /var/lib/docker）
          # 注意：不可写 `dpkg -l | grep -q`——全量 dpkg -l 输出被 grep -q 提前关闭管道，
          #   pipefail 下 dpkg 得 SIGPIPE(141)，条件永远为假，卸载静默跳过。限定包名后输出短，无此问题。
          if dpkg -l docker-ce 2>/dev/null | grep -q '^ii'; then
            ''${SUDO} apt-get purge -y docker-ce docker-ce-cli containerd.io \
                docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras \
              || echo "警告: apt docker 包卸载失败（nix 单元仍会接管 daemon，残留包不影响运行）"
          fi

          # 非登录 shell 与 systemd 的 PATH 首位是 /usr/local/bin，shim 保证拿到 nix 版
          ''${SUDO} ln -sf ${pkgs.docker}/bin/docker /usr/local/bin/docker
          ''${SUDO} ln -sf ${pkgs.docker-compose}/bin/docker-compose /usr/local/bin/docker-compose
          ''${SUDO} ln -sf ${pkgs.docker-buildx}/bin/docker-buildx /usr/local/bin/docker-buildx

          # daemon 配置（镜像加速）：必须写在启动前
          if [ "${if useChinaMirror then "true" else "false"}" = true ]; then
            echo '{"registry-mirrors": ${builtins.toJSON tools.config.dockerRegistryMirrors}}' \
              | ''${SUDO} tee /etc/docker/daemon.json > /dev/null
          fi

          ''${SUDO} systemctl daemon-reload
          ''${SUDO} systemctl enable --now docker.socket > /dev/null 2>&1 \
            || echo "警告: docker.socket 启用失败"
          ''${SUDO} systemctl enable --now docker > /dev/null 2>&1 \
            || echo "警告: nix docker 服务启动失败（journalctl -u docker 查因）"
          echo "===> docker daemon: $( ''${SUDO} ${pkgs.docker}/bin/docker version --format '{{.Server.Version}}' 2>/dev/null || echo 未就绪 )"
        else
          # 2a) 未接管：沿用系统单元（Ubuntu apt docker / Alpine 自装）
          if command -v systemctl > /dev/null 2>&1; then
            ''${SUDO} systemctl enable docker > /dev/null 2>&1 || true
            ''${SUDO} systemctl start docker > /dev/null 2>&1 \
              || echo "警告: docker 服务启动失败（容器内需特权？）"
          elif command -v rc-update > /dev/null 2>&1; then
            ''${SUDO} rc-update add docker boot > /dev/null 2>&1 || true
            ''${SUDO} service docker start > /dev/null 2>&1 \
              || echo "警告: docker 服务启动失败"
          else
            echo "警告: 无 systemctl/rc-update，跳过 docker 自启（容器环境请用特权 + 手动启动）"
          fi

          # 2b) 国内镜像加速（useChinaMirror 开关，与 mirrors.nix 同语义）：写 /etc/docker/daemon.json
          #     只在 Ubuntu/PVE 上写（NixOS 走 podman registries.conf.d，本模块在 nixos 不生效）
          if [ "${if useChinaMirror then "true" else "false"}" = true ]; then
            ''${SUDO} mkdir -p /etc/docker
            echo '{"registry-mirrors": ${builtins.toJSON tools.config.dockerRegistryMirrors}}' \
              | ''${SUDO} tee /etc/docker/daemon.json > /dev/null
            echo "===> 已写入 /etc/docker/daemon.json（registry-mirrors 国内镜像）"
          fi
        fi

        # 3) dc 软链（对应脚本 ln -s docker-compose /usr/bin/dc）
        ''${SUDO} ln -sf ${pkgs.docker-compose}/bin/docker-compose /usr/bin/dc \
          || echo "警告: dc 软链失败（/usr/bin 不可写？）"

        # 4) docker network fan（对应脚本 --subnet 172.88.0.0/16，幂等：已存在则跳过）
        if ! ${pkgs.docker}/bin/docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx 'fan'; then
          ${pkgs.docker}/bin/docker network create --subnet 172.88.0.0/16 fan > /dev/null 2>&1 \
            || echo "警告: docker network fan 创建失败（daemon 未运行？）"
        fi
      }
      setup_docker
    ''
  );
  };
}
