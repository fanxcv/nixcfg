# razer（10.2.241.80，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：GTX 1660 Ti 直通的 GRUB 与 modprobe 参数；公共值见 pve/default.nix
{ pkgs, lib, ... }:
let
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
import ../mkHost.nix {
  inherit pkgs lib modprobeHost;
  hostName = "razer";
  ip = "10.2.241.80/24";
  extra = [
    "initcall_blacklist=sysfb_init"
    "pcie_acs_override=downstream"
    "video=vesafb:off"
    "video=efifb:off"
  ];
}
