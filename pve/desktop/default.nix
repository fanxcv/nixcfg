# desktop（10.2.241.208，PVE 9.x 宿主机，Debian 13 trixie）系统层定义
# 机器专属：vfio 直通核显（8086:3185）+ 声卡/i915 黑名单 + zfs arc 限制（同名覆盖原文件）
# 公共参数（DNS/mirror/grubCmdline/modprobePublic）来自 pve/default.nix
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  ip = "10.2.241.208/24";                        # 静态 IP（apply 写 vmbr0）
  gateway = "10.2.241.254";
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
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline;             # 公共：quiet consoleblank=60 intel_iommu=on iommu=pt
  inherit modprobeHost;
  inherit ip gateway;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
    modprobePublic = common.modprobePublic;
    inherit modprobeHost;
    inherit ip gateway;
  };
}
