# docker + docker-compose（对应 alpine-init.sh 的 install_docker()）
# 本层只被 _nixos_/_alpine_ 导入，天然仅 Linux 生效（mac 不装），无需再判平台
# nix 侧统一用官方包，不区分发行版源：
#   pkgs.docker          → 脚本的 apk docker / apt docker-ce（client + daemon）
#   pkgs.docker-compose  → 脚本手动下载的 release 二进制（v2）
#   pkgs.docker-buildx   → 脚本 Ubuntu 分支的 docker-buildx-plugin（nix 侧统一提供）
# 自启 + dc 软链 + network fan 由 home.activation 完成（需 root 或 sudo NOPASSWD）
# 容器环境不安装：isContainer 由 flake.nix 传入（ide 容器 = true，真机默认 false），
#   包与 activation 均 mkIf 跳过——容器里 docker daemon 起不来，连检测都不跑

{ pkgs, lib, isContainer ? false, useChinaMirror ? true, platform ? "linux", ... }:
{
  home.packages = lib.mkIf (!isContainer) (with pkgs; [
    docker
    docker-compose
    docker-buildx
  ]);

  home.activation.setupDocker = lib.mkIf (!isContainer) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
      #    NixOS 真机跳过（nix-pve 由系统层 virtualisation.docker.daemon.settings 声明式管，
      #    HM 写普通文件会覆盖其 symlink，rebuild 后丢失）
      if [ "${if useChinaMirror then "true" else "false"}" = true ] && [ "${platform}" != nixos ]; then
        echo '{"registry-mirrors": ["https://docker.xuanyuan.me", "https://docker.1ms.run", "https://docker.m.daocloud.io"]}' \
          | ''${SUDO} tee /etc/docker/daemon.json > /dev/null
        echo "===> 已写入 /etc/docker/daemon.json（registry-mirrors 国内镜像）"
      fi
    }
    setup_docker
  '');
}
