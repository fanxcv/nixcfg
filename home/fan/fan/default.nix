# fan（10.2.241.88，PVE 9.2 宿主机）—— home 层仅安装 tailscale。
# 公共/平台层由 home/fan/module-list.nix 注入；系统层见 pve/fan/。
# state 由 secrets/hosts/fan/tailscale-state.age 管理。
{ tools, pkgs, ... }:
{
  imports = tools.scan ./.;
  home.packages = [ pkgs.tailscale ];
}
