# mi（10.2.241.92，PVE 9.2 宿主机）home 层安装 tailscale 与 podman；系统层见 pve/mi/
# tailscale state 由 secrets/hosts/mi/tailscale-state.age 管理
{ pkgs, ... }:
{
  home.packages = [
    pkgs.tailscale
    pkgs.podman
  ];
}
