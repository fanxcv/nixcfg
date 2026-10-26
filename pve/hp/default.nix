# hp（10.2.237.149，HP ProBook 450 G10 笔记本，PVE 9.2 宿主机）系统层定义
# 机器专属：iGPU 直通给 VM 101（fnos）、盒盖不休眠；直通/虚拟化 modprobe 全部 nix 声明
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  modprobeHost = {
    "blacklist.conf" = ''
      # 由 nixcfg 渲染（hp 专属）：i915 让给 vfio，声卡不进宿主
      blacklist i915
      blacklist snd_hda_intel
      blacklist snd_hda_codec_hdmi
    '';
    "kvm.conf" = "options kvm ignore_msrs=Y report_ignored_msrs=0";
    "kvm-intel.conf" = "options kvm-intel nested=Y";
    # PVE 官方默认内容，覆盖历史手配（nvidia/radeon/amdgpu 等无关黑名单已清掉）
    "pve-blacklist.conf" = ''
      # This file contains a list of modules which are not supported by Proxmox VE
      # nvidiafb see bugreport https://bugzilla.proxmox.com/show_bug.cgi?id=701
      blacklist nvidiafb
    '';
    # 原手配误写 8086:3185（N100 核显），本机实际是 Raptor Lake Iris Xe 8086:a7a0
    "vfio.conf" = "options vfio-pci ids=8086:a7a0";
  };
  hpExtra = ''
    echo "==> [6.5/7] 笔记本专属：盒盖不休眠"
    mkdir -p /etc/systemd/logind.conf.d
    cat > /etc/systemd/logind.conf.d/10-lid-ignore.conf <<'EOF'
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
    EOF
    systemctl restart systemd-logind
    echo "lid ignore 已配置（合盖不休眠）"
  '';
in
import ../mkHost.nix {
  inherit
    pkgs
    lib
    modprobeHost
    hpExtra
    ;
  hostName = "hp";
  ip = "10.2.237.149/23";
  gateway = "10.2.237.254";
  modules = [
    "coretemp"
    "vfio"
    "vfio_iommu_type1"
    "vfio_pci"
    "vfio_virqfd"
  ];
  obsoleteModprobe = [ "iommu_unsafe_interrupts.conf" ]; # DMAR-IR 已启用，无需 unsafe interrupts
}
