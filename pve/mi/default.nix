# mi（10.2.241.92，原 pve 节点改名而来，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：modprobe kvm ignore_msrs + 核显/声卡黑名单（原 pve-blacklist.conf，同名覆盖）
# tailscaleState：mi 专属——tailscale state nix 化（换机/重建恢复同 IP 10.1.0.25）
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  modprobeHost = {
    "kvm.conf" = "options kvm ignore_msrs=1";
    "pve-blacklist.conf" = ''
      # 由 nixcfg 渲染（mi 专属，原 pve-blacklist.conf 同名覆盖）；nvidiafb 见公共 nixcfg-public.conf
      blacklist i915
      blacklist snd_hda_intel
      blacklist snd_hda_codec_hdmi
      options vfio_iommu_type1 allow_unsafe_interrupts=1
    '';
  };
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # 从 8.4（bookworm）升级至 9.2
  grubCmdline = common.grubCmdline;
  inherit modprobeHost;
  tailscaleState = ../../secrets/tailscale-mi-state.age;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
    modprobePublic = common.modprobePublic;
    inherit modprobeHost;
    tailscaleForward = true;
  };
}
