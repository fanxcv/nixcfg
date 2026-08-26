# desktop（10.2.241.208，PVE 9.x 宿主机，Debian 13 trixie）系统层定义
# 机器专属：vfio 直通核显（8086:3185）+ 声卡/i915 黑名单 + zfs arc 限制
{ pkgs, lib, ... }:
import ../mkHost.nix {
  inherit pkgs lib;
  hostName = "desktop";
  ip = "10.2.241.208/24";
  modprobeHost = {
    "blacklist.conf" = ''
      # 由 nixcfg 渲染（desktop 专属）
      blacklist snd_hda_intel
      blacklist snd_hda_codec_hdmi
      blacklist i915
    '';
    "intel-microcode-blacklist.conf" = "blacklist microcode";
    "vfio.conf" = "options vfio-pci ids=8086:3185";
    "zfs.conf" = "options zfs zfs_arc_max=3344957440";
  };
}
