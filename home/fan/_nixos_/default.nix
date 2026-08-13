# Linux/NixOS 专属配置（NixOS 机器与 Linux 容器共用）
# 跨平台配置在 ../_common_/，Linux 系公共在 ../_linux_/，机器微调在 ../<host>/
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效（当前：base.nix + gui/ + i18n/）

{ tools, ... }:
{
  imports = [ ../_linux_ ] ++ tools.scan ./.;

  # standalone 入口（home/fan/default.nix）不参与内嵌模式，这里补 stateVersion
  home.stateVersion = "25.05";
}
