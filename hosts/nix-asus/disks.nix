# 双系统磁盘声明（手写 fileSystems，不用 disko）
#
# 为何不用 disko：disko 的 gpt 类型会 `sgdisk --clear` 重写整盘分区表（毁 Windows），
#   legacy table 类型只补建声明分区且已废弃 —— 双系统场景都不合适。本机分区表由安装时手工
#   sgdisk/parted 建立，此处只声明挂载，保证 eval 与运行期一致。
#
# 实际布局（Micron 3400 512G，GPT）：
#   p1 260M  Windows ESP        （不动）
#   p2 16M   MSR                （不动）
#   p3 219G  Windows C: NTFS    （不动）
#   p6 1G    NIXOS-ESP  vfat    → /boot/efi   （空闲区起点 220G）
#   p7 255G  LVM PV → VG pool
#     ├ boot    1G   ext4 → /boot
#     ├ swap   16G        → hibernate（14G 内存）
#     ├ persist 115G ext4 → /persist
#     └ nix     118G ext4 → /nix（余 ~5G 留给 lvextend）
#   p4 1.1G  RECOVERY / p5 200M MYASUS （不动，位于盘尾）
# 根为 tmpfs（不可变系统，持久化清单见 hosts/_nixos_/base/immutable.nix）
#
# 首次安装（手工，仓库须在 /mnt/persist/etc/nixos）：
#   sgdisk -n 6:220GiB:+1GiB -t 6:EF00 -c 6:NIXOS-ESP /dev/nvme0n1
#   sgdisk -n 7:0:0 -t 7:8E00 -c 7:NIXOS-LVM /dev/nvme0n1
#   mkfs.vfat -F32 -n NIXOS-ESP /dev/nvme0n1p6
#   pvcreate /dev/nvme0n1p7 && vgcreate pool /dev/nvme0n1p7
#   lvcreate -L 1G -n boot pool && lvcreate -L 16G -n swap pool
#   lvcreate -L 115G -n persist pool && lvcreate -L 118G -n nix pool
#   mkfs.ext4 -L boot /dev/pool/boot && mkfs.ext4 -L persist /dev/pool/persist
#   mkfs.ext4 -L nix /dev/pool/nix && mkswap /dev/pool/swap
{
  fileSystems = {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "x-initrd.mount"
        "size=2G"
        "mode=0755"
      ];
    };
    "/tmp" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "size=2G" ];
    };
    "/boot" = {
      device = "/dev/pool/boot";
      fsType = "ext4";
      options = [ "defaults" ];
    };
    "/boot/efi" = {
      device = "/dev/disk/by-partlabel/NIXOS-ESP";
      fsType = "vfat";
      options = [
        "defaults"
        "umask=0077"
      ];
    };
    "/nix" = {
      device = "/dev/pool/nix";
      fsType = "ext4";
      options = [
        "x-initrd.mount"
        "defaults"
      ];
    };
    "/persist" = {
      device = "/dev/pool/persist";
      fsType = "ext4";
      options = [
        "x-initrd.mount"
        "defaults"
      ];
      neededForBoot = true;
    };
  };

  swapDevices = [
    { device = "/dev/pool/swap"; }
  ];
}
