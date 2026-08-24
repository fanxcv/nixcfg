# fan（10.2.241.88，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：GRUB video=efifb:off,vesafb:off（核显直通，Iris Plus 655 / 8086:3ea5）
# modprobe：kvm ignore_msrs / vfio 直通 / 声卡黑名单（同名覆盖原文件）；公共 nvidiafb 见 common
# tailscaleState：fan 专属——tailscale state nix 化（换机/重建恢复同 IP 10.1.0.16）
# 注意：modprobeHost 键含点必须引号（kvm.conf 无引号会被解析为嵌套 kvm = { conf = ... }）
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  extra = [ "video=efifb:off,vesafb:off" ];
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
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline ++ extra;
  inherit modprobeHost;
  tailscaleState = ../../secrets/tailscale-fan-state.age;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline ++ extra;
    modprobePublic = common.modprobePublic;
    inherit modprobeHost;
  };
}
