# 硬件配置：Proxmox VE 虚拟机（qemu-guest profile：virtio 磁盘/网卡/固件）
# PVE 创建 VM 时建议：OVMF (UEFI) + virtio 磁盘 + virtio 网卡
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # GRUB 引导（efiInstallAsRemovable：OVMF 兼容性最好，PVE 无需额外配置）
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    configurationLimit = 15;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # VM 内存通常较小，zram 压缩提效
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;
  zramSwap.algorithm = "zstd";

  boot.kernel.sysctl = {
    "vm.swappiness" = 15;
  };
}
