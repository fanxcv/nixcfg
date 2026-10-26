# fan（10.2.241.88，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：tailscale 网关与 state 归档；核显直通准备已弃用（无 VM），vfio/黑名单/efifb 参数一并移除
{ pkgs, lib, ... }:
import ../mkHost.nix {
  inherit pkgs lib;
  hostName = "fan";
  ip = "10.2.241.88/24";
  modules = [ "coretemp" ];
  obsoleteModprobe = [
    "kvm.conf"
    "pve-blacklist.conf"
    "vfio.conf"
  ];
  tailscaleForward = true;
  tailscaleState = ../../secrets/hosts/fan/tailscale-state.age;
}
