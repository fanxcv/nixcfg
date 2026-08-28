# 硬件配置：无界14S 笔记本（AMD Ryzen 7 7840HS + Radeon 780M 核显 + Intel AX200 WiFi）
# 真机（非 VM）：无 qemu-guest profile；amdgpu 用户态驱动 + 核显固件（linux-firmware 默认带）
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

  # AMD 核显用户态驱动（mesa/vaapi；内核 amdgpu 驱动 + 固件默认启用）
  hardware.graphics.enable = true;

  # 无线固件：nixpkgs 26.05 起默认 firmware 仅 wireless-regdb，linux-firmware 需显式启用
  # （iwlwifi AX200 缺固件则接口不出现：dmesg 'iwlwifi-cc-a0-77.ucode failed'）
  hardware.enableRedistributableFirmware = true;

  # 12G 内存，zram 压缩提效
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
  zramSwap.algorithm = "zstd";

  boot.kernel.sysctl = {
    "vm.swappiness" = 15;
  };

  # 笔记本电源：系统层无 TLP（tsln 同款，电源计划全在 plasma.powerdevil，见 home/fan/nix-book/）
  # 休眠恢复：swap LV 已标 resumeDevice（disks.nix），内核 initrd 自动带 resume 参数
  boot.resumeDevice = "/dev/pool/swap";
}
