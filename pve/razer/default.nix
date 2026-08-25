# razer（10.2.241.80，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属 GRUB：N 卡直通（GTX 1660 Ti Mobile / 10de:2191）——initcall_blacklist=sysfb_init
# + pcie_acs_override=downstream + video=vesafb:off,efifb:off
# modprobe：nvidia/nouveau 黑名单 + vfio ids + kvm 参数（同名覆盖原文件）
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  ip = "10.2.241.80/24";                        # 静态 IP（apply 写 vmbr0）
  gateway = "10.2.241.254";
  extra = [ "initcall_blacklist=sysfb_init" "pcie_acs_override=downstream" "video=vesafb:off" "video=efifb:off" ];
  modprobeHost = {
    "blacklist.conf" = ''
      # 由 nixcfg 渲染（razer 专属）
      blacklist nvidia
      blacklist nouveau
      blacklist radeon
      blacklist i2c_nvidia_gpu
      blacklist nvidiafb
      blacklist nvidia_drm
      options nouveau modeset=0
    '';
    "iommu_unsafe_interrupts.conf" = "options vfio_iommu_type1 allow_unsafe_interrupts=1";
    "kvm.conf" = "options kvm ignore_msrs=1";
    "mdadm.conf" = "options md_mod start_ro=1";
    "vfio.conf" = "options vfio-pci ids=10de:2191,10de:1aeb,10de:1aec,10de:1aed disable_vga=1";
  };
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline ++ extra;
  inherit modprobeHost;
  inherit ip gateway;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline ++ extra;
    modprobePublic = common.modprobePublic;
    inherit modprobeHost;
    inherit ip gateway;
  };
}
