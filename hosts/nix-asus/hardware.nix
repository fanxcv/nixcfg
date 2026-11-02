# 硬件配置：ASUS Zenbook UM5302TA（AMD Ryzen 7 6800U + Radeon 680M 核显 + MediaTek MT7922 无线）
# 真机（非 VM）：无 qemu-guest profile；amdgpu 用户态驱动 + 核显固件（linux-firmware 默认带）
_: {
  # GRUB 引导：本机有 Windows 双系统，EFI 分区为 NixOS 独有（p6，见 disks.nix），
  # 故不用 efiInstallAsRemovable（那是单系统回退路径写法），改由 efibootmgr 写 NVRAM 条目
  # 指向本 ESP 的 \EFI\NixOS\grubx64.efi（两块 ESP 时固件回退路径不保证选中 NixOS 那块）
  # useOSProber：尝试生成 Windows 项——os-prober 只在已挂载分区里探测，
  #   第二块 ESP（Windows 的 p1）未挂载时探不到，故用 extraEntries 显式 chainload 兜底
  #   （D0FF-EB18 = Windows ESP p1 的 FAT UUID；Windows 引导文件为 p1:/EFI/Microsoft/Boot/bootmgfw.efi）
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 15;
    extraEntries = ''
      menuentry "Windows" --class windows --class os {
        insmod part_gpt
        insmod fat
        insmod chain
        search --no-floppy --fs-uuid --set=root D0FF-EB18
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # 核显驱动、固件、zram、swappiness、ESP 挂点已在公共层（hosts/_nixos_/base）

  # 休眠恢复：swap 分区（16G，见 disks.nix）为 resume 目标，内核 initrd 自动带 resume 参数
  boot.resumeDevice = "/dev/disk/by-partlabel/NIXOS-SWAP";
}
