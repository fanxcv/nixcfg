# NixOS 专属配置（NixOS 真机，如 nix-pve；Ubuntu 容器已拆到 ../_container_/）
# 跨平台配置在 ../_common_/，Linux 系公共在 ../_linux_/，机器微调在 ../<host>/
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效（当前：gui/ + i18n/）

{ tools, ... }:
{
  imports = [ ../_linux_ ] ++ tools.scan ./.;
}
