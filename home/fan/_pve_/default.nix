# PVE 平台层（Proxmox VE 宿主机，Debian 底；当前：ds2）
# PVE 用户身份由 ../_common_/identity.nix 统一设为 root；本层只保留 PVE 软件。
# 系统层配置（apt 源 / DNS / 去订阅 nag）不走 HM——PVE 非 NixOS，见 pve/ 目录（nix 渲染 + 推送 + apply）
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效

{
  pkgs,
  tools,
  ...
}:
{
  imports = [ ../_linux_ ] ++ tools.scan ./.;

  # age：ts-state/lucky 归档在 PVE 侧解密（/root/.nix-profile/bin/age，secrets 归档 .age 原文件推送）
  # fuse3：fusermount3 用户态工具（原 apt 装，nix 化；内核模块 /dev/fuse 由 PVE 内核自带）
  home.packages = [
    pkgs.age
    pkgs.fuse3
  ];
}
