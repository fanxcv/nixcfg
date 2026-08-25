# PVE 平台层（Proxmox VE 宿主机，Debian 底；当前：ds2）
# PVE 默认 root 用户 → 覆盖平台默认用户为 root（同容器语义，见 _common_/container.nix）
# 系统层配置（apt 源 / DNS / 去订阅 nag）不走 HM——PVE 非 NixOS，见 pve/ 目录（nix 渲染 + 推送 + apply）
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效

{
  pkgs,
  lib,
  tools,
  platform ? "nixos",
  ...
}:
{
  imports = [ ../_linux_ ] ++ tools.scan ./.;

  # age：自部署模式（--self）本地解密 ts-state/lucky 归档必需（secrets 推送原在 mac 侧解密）
  # fuse3：fusermount3 用户态工具（原 apt 装，nix 化；内核模块 /dev/fuse 由 PVE 内核自带）
  home.packages = [ pkgs.age pkgs.fuse3 ];

  # standalone 入口（home/fan/default.nix）不参与内嵌模式，这里补 stateVersion
  home.stateVersion = "25.05";

  # PVE 无独立用户，日常管理即 root（与 alpine 同语义）
  home.username = lib.mkIf (platform == "pve") (lib.mkForce "root");
  home.homeDirectory = lib.mkIf (platform == "pve") (lib.mkForce "/root");

  # root 无 user systemd：覆盖 reloadSystemd 钩子为空脚本，
  # 消除每次激活的 "User systemd daemon not running. Skipping reload." 警告
  # （同 _common_/container.nix 的容器处理；PVE 系统服务启停由 pve/ 部署脚本直接调 systemctl）
  home.activation.reloadSystemd = lib.mkIf (platform == "pve") (
    lib.mkForce (lib.hm.dag.entryAfter [ "linkGeneration" ] "")
  );
}
