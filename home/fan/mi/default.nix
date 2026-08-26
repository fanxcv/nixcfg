# mi（10.2.241.92，PVE 9.2 宿主机）—— home 层安装 tailscale 与 podman。
# 公共/平台层由 home/fan/module-list.nix 注入；系统层见 pve/mi/。
# tailscale state 由 secrets/hosts/mi/tailscale-mi-state.age 管理。
{ tools, pkgs, ... }:
{
  imports = tools.scan ./.;
  home.packages = [
    pkgs.tailscale
    pkgs.podman
  ];
}
