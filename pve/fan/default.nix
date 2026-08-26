# fan（10.2.241.88，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：核显直通、tailscale 网关与 tailscale state 归档；公共值见 pve/default.nix
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  modprobeHost = {
    "kvm.conf" = "options kvm ignore_msrs=1";
    "pve-blacklist.conf" = ''
      # 由 nixcfg 渲染（fan 专属）；nvidiafb 见公共 nixcfg-public.conf
      blacklist snd_hda_codec_hdmi
      blacklist i915
      blacklist snd_hda_intel
      options vfio_iommu_type1 allow_unsafe_interrupts=1
    '';
    "vfio.conf" = "options vfio-pci ids=8086:3ea5";
  };
in
import ../mkHost.nix {
  inherit pkgs lib modprobeHost;
  hostName = "fan";
  ip = "10.2.241.88/24";
  extra = [ "video=efifb:off,vesafb:off" ];
  tailscaleForward = true;
  tailscaleState = ../../secrets/hosts/fan/tailscale-state.age;
}
