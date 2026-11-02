# 硬件配置：Lenovo ThinkBook 14 G6+ AHP（AMD Ryzen 7 8845H + Radeon 780M 核显 + MediaTek MT7921 无线 + Realtek RTL8111 有线）
# 真机（非 VM）：无 qemu-guest profile；amdgpu 用户态驱动 + 核显固件（linux-firmware 默认带）
_: {
  # GRUB 引导（efiInstallAsRemovable：真机 UEFI 兼容性最好，无需额外配置）
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    configurationLimit = 15;
    efiInstallAsRemovable = true;
  };
  # AMD 核显用户态驱动、固件、zram、swappiness、ESP 挂点已在公共层（hosts/_nixos_/base）

  # 笔记本电源：系统层无 TLP（tsln 同款，电源计划全在 plasma.powerdevil，见 home/fan/nix-lenovo/）
  # 休眠恢复：swap 分区的 resumeDevice 由 disko 从 disks.nix 生成，无需手写
}
