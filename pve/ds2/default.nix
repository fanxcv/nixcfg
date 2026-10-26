# ds2（10.2.241.104，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：无（LVM 无 ZFS；无直通、无 tailscale）；公共值见 pve/default.nix
{ pkgs, lib, ... }:
import ../mkHost.nix {
  inherit pkgs lib;
  hostName = "ds2";
  ip = "10.2.241.104/24";
}
