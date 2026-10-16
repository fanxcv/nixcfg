# NixOS 专属配置（NixOS 真机，如 nix-pve；Ubuntu 容器已拆到 ../_container_/）
# 跨平台配置在 ../_common_/，Linux 系公共在 ../_linux_/，机器微调在 ../<host>/
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效（当前：gui/ + i18n/ + themes/）
# catppuccin 上游 home 模块只挂本层：非 NixOS 平台不持有 catppuccin.* 选项
# （自封装 target 见 ./themes/catppuccin/）

{
  tools,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ../_linux_
    inputs.catppuccin.homeModules.catppuccin
  ]
  ++ tools.scan ./.;

  # 三台 NixOS 真机均装 pi agent：平台层给默认值，机器层可 mkForce 覆盖
  softwares.pi.enable = lib.mkDefault true;
}
