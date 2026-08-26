# ds2（10.2.241.104，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：zfs_arc_max（zfs 缓存上限 3.1G）与 microcode 黑名单；公共值见 pve/default.nix
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
import ../mkHost.nix {
  inherit pkgs lib;
  hostName = "ds2";
  ip = "10.2.241.104/24";
  modprobeHost = {
    "intel-microcode-blacklist.conf" = "blacklist microcode";
    "zfs.conf" = "options zfs zfs_arc_max=3341811712";
  };
}
