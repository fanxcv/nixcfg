# 硬件配置：Lenovo ThinkBook 14 G6+ IMH（Intel Core Ultra 5 125H + Arc 核显 + Intel CNVi 无线 + Intel I219-LM 有线）
# 真机（非 VM）：无 qemu-guest profile；Arc 走内核 xe/i915 + mesa（linux-firmware 默认带）
{ lib, pkgs, ... }:
{
  # GRUB 引导（efiInstallAsRemovable：真机 UEFI 兼容性最好，无需额外配置）
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    configurationLimit = 15;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # Intel 微码：Meteor Lake 的 downcore/安全修复靠它（nix-lenovo 是 AMD，无此项）
  hardware.cpu.intel.updateMicrocode = true;

  # 核显用户态驱动（mesa/vaapi；内核驱动 + 固件默认启用）
  hardware.graphics.enable = true;
  # Arc 的硬件解码走 iHD 驱动（home 层 mpv.conf hwdec=vaapi 依赖它，AMD 机不需要）
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # 无线固件：nixpkgs 26.05 起默认 firmware 仅 wireless-regdb，linux-firmware 需显式启用
  # （Intel CNVi 缺 iwlwifi 固件则接口不出现：dmesg iwlwifi ... failed to load firmware）
  hardware.enableRedistributableFirmware = true;

  # 30G 内存，zram 压缩提效
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
  zramSwap.algorithm = "zstd";

  boot.kernel.sysctl = {
    "vm.swappiness" = 15;
  };

  # 笔记本电源：系统层无 TLP（tsln 同款，电源计划全在 plasma.powerdevil，见 home/fan/nix-im/）
  # 休眠恢复：swap LV 已标 resumeDevice（disks.nix），内核 initrd 自动带 resume 参数
  # swap 32G ≥ 内存 30G，hibernate 才可靠（zram 是压缩内存，不可作为休眠目标）
  boot.resumeDevice = "/dev/pool/swap";
}
