# fan（10.2.241.88，PVE 9.2 宿主机）home 层仅安装 tailscale；系统层见 pve/fan/
# tailscale state 由 secrets/hosts/fan/tailscale-state.age 管理
{ pkgs, ... }:
{
  home.packages = [ pkgs.tailscale ];
}
