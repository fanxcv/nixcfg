# macOS 用户层配置（home-manager，内嵌于 nix-darwin）
# 自动扫描导入：新增 .nix 文件即生效

{ pkgs, tools, lib, ... }:
{
  imports = tools.scan ./.;

  # darwin 用户身份固定 fan（内嵌模式下由 users/fan 的 home-manager.users 挂载）
  home.username = "fan";
  home.homeDirectory = "/Users/fan";
  # standalone 入口（home/fan/default.nix）不参与 darwin 内嵌，这里补 stateVersion
  home.stateVersion = "25.05";
}
