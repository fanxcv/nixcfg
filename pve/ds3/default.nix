# ds3（10.2.241.206，PVE 9.2 宿主机，Debian 13 trixie；i7-12700 / 30G / 单 NVMe LVM）系统层定义
# 机器专属：无（LVM 无 ZFS；无直通、无 tailscale）；公共值见 pve/default.nix
{ pkgs, lib, ... }:
import ../mkHost.nix {
  inherit pkgs lib;
  hostName = "ds3";
  ip = "10.2.241.206/24";
}
