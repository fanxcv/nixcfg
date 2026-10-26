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

{
  pkgs,
  lib,
  tools,
  isContainer ? false,
  useChinaMirror ? true,
  platform ? "linux",
  ...
}:
let
  enabled = !isContainer && platform != "nixos";
in
{
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

        # 1) dc 软链（对应脚本 ln -s docker-compose /usr/bin/dc）
        ''${SUDO} ln -sf ${pkgs.docker-compose}/bin/docker-compose /usr/bin/dc \
          || echo "警告: dc 软链失败（/usr/bin 不可写？）"

        # 2) 自启：Ubuntu 走 systemctl，Alpine 走 rc-update；无服务管理器则跳过
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

        # 3) docker network fan（对应脚本 --subnet 172.88.0.0/16，幂等：已存在则跳过）
        if ! ${pkgs.docker}/bin/docker network ls --format '{{.Name}}' 2>/dev/null | grep -qx 'fan'; then
          ${pkgs.docker}/bin/docker network create --subnet 172.88.0.0/16 fan > /dev/null 2>&1 \
            || echo "警告: docker network fan 创建失败（daemon 未运行？）"
        fi

        # 4) 国内镜像加速（useChinaMirror 开关，与 mirrors.nix 同语义）：写 /etc/docker/daemon.json
        #    只在 Ubuntu/PVE 上写（NixOS 走 podman registries.conf.d，本模块在 nixos 不生效）
        if [ "${if useChinaMirror then "true" else "false"}" = true ]; then
          ''${SUDO} mkdir -p /etc/docker
          echo '{"registry-mirrors": ${builtins.toJSON tools.config.dockerRegistryMirrors}}' \
            | ''${SUDO} tee /etc/docker/daemon.json > /dev/null
          echo "===> 已写入 /etc/docker/daemon.json（registry-mirrors 国内镜像）"
        fi
      }
      setup_docker
    ''
  );
}
