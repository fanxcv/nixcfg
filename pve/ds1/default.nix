# ds1（10.2.241.208，PVE 9.x 宿主机，Debian 13 trixie；原 desktop，2026-10 改名）系统层定义
# 机器专属：无（核显由 i915 驱动，未做直通）；历史 vfio/黑名单配置已废弃，由 apply 删除
{ pkgs, lib, ... }:
import ../mkHost.nix {
  inherit pkgs lib;
  hostName = "ds1";
  ip = "10.2.241.208/24";
  modules = [
    "coretemp"
    "nct6683"
  ];
  obsoleteModprobe = [
    "blacklist.conf"
    "vfio.conf"
  ];
}
