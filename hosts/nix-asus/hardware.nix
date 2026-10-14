# 硬件配置：ASUS Zenbook UM5302TA（AMD Ryzen 7 6800U + Radeon 680M 核显 + MediaTek MT7922 无线）
# 真机（非 VM）：无 qemu-guest profile；amdgpu 用户态驱动 + 核显固件（linux-firmware 默认带）
{ pkgs, ... }:
{
  # GRUB 引导：本机有 Windows 双系统，EFI 分区为 NixOS 独有（p6，见 disks.nix），
  # 故不用 efiInstallAsRemovable（那是单系统回退路径写法），改由 efibootmgr 写 NVRAM 条目
  # 指向本 ESP 的 \EFI\NixOS\grubx64.efi（两块 ESP 时固件回退路径不保证选中 NixOS 那块）
  # useOSProber：生成 GRUB 菜单里的 Windows 项（Windows Boot Manager 在 p1 的 ESP 上）
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 15;
  };
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.efi.canTouchEfiVariables = true;

  # AMD 核显用户态驱动（mesa/vaapi；内核 amdgpu 驱动 + 固件默认启用）
  hardware.graphics.enable = true;

  # 无线/蓝牙固件：nixpkgs 26.05 起默认 firmware 仅 wireless-regdb，linux-firmware 需显式启用
  # （MT7922 缺固件则接口不出现：dmesg mt7921e ... failed）
  hardware.enableRedistributableFirmware = true;

  # 14G 内存，zram 压缩提效
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
  zramSwap.algorithm = "zstd";

  boot.kernel.sysctl = {
    "vm.swappiness" = 15;
  };

  # 休眠恢复：swap LV（16G，见 disks.nix）为 resume 目标，内核 initrd 自动带 resume 参数
  boot.resumeDevice = "/dev/pool/swap";
}
