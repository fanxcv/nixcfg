# mi（10.2.241.92，原 pve 节点改名，PVE 9.2 宿主机）—— home 层机器微调（HM standalone，root 用户）
# 组装：_common_（跨平台）+ _pve_（PVE 平台层）+ 本机微调
# 系统层（apt 源/DNS/去 nag/pve-assist/modprobe/tailscale unit）见 pve/mi/，部署：nix run .#mi
# tailscale：nix 包（HM profile），state 由 secrets/hosts/mi/tailscale-mi-state.age 管理（换机/重建恢复同 IP）
# podman：nix 包（lucky quadlet 用；system-generator 链接见 pve/mi/default.nix miExtra）
{ tools, pkgs, ... }:
{
  imports = [ ../_common_ ../_pve_ ] ++ tools.scan ./.;
  home.packages = [ pkgs.tailscale pkgs.podman ];
}
