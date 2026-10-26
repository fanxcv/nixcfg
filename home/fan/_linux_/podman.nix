# podman + podman-compose 运行时（Ubuntu 发行版层用 podman 取代 docker）
# 本层被 _nixos_/_ubuntu_/_pve_/_container_ 导入 -> Linux 生效（mac 不装）
# 默认关闭：只有机器层显式设 softwares.podman.enable = true 才装（当前无机器启用）
# Ubuntu 上 podman 无 daemon：容器靠 `restart: always` 的 podman-restart.service 开机拉起，
#   故 activation 把包内 unit 拷到 /etc/systemd/system 并 enable --now
# NixOS 真机不走本模块（其运行时在 hosts/_nixos_/services/podman.nix，由系统层声明）

{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.softwares.podman;
in
{
  options.softwares.podman.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "是否安装 podman + podman-compose 并启用 podman-restart.service（Ubuntu 发行版层取代 docker）";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.podman
      pkgs.podman-compose
    ];

    home.activation.setupPodman = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PODMAN="${pkgs.podman}/bin/podman"
      PODMAN_RESTART_UNIT="${pkgs.podman}/lib/systemd/system/podman-restart.service"

      # 1) 安装开机自启 unit（重启后把 restart=always 的容器重新拉起；无 daemon 故无 enable 服务）
      /usr/bin/systemctl daemon-reload
      cp -f "$PODMAN_RESTART_UNIT" /etc/systemd/system/podman-restart.service \
        || echo "警告: podman-restart.service 拷贝失败（/etc/systemd/system 不可写？容器内需特权？）"
      /usr/bin/systemctl daemon-reload
      /usr/bin/systemctl enable --now podman-restart.service \
        || echo "警告: podman-restart.service 启用失败（容器重启后需手动 podman start）"

      echo "===> podman: $("$PODMAN" --version)"
    '';
  };
}
