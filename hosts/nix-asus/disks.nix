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
#   p7 16G   NIXOS-SWAP swap    → hibernate（14G 内存，连续块设备才能恢复）
#   p8 239G  NIXOS-POOL btrfs   → 子卷 @root/@boot/@persist/@nix 共一池，无定长卷
#   p4 1.1G  RECOVERY / p5 200M MYASUS （不动，位于盘尾）
# 根是 btrfs 子卷 @root（不可变系统，持久化清单见 hosts/_nixos_/base/immutable.nix；
#   每次开机由 initrd 擦根，见 hosts/_nixos_/base/root-on-btrfs.nix）
# ⚠ 空间耦合：单池下 /persist 写爆会连带打穿 /nix 与根
# ⚠ 改造会删掉 p7 的 LVM（原 boot/swap/persist/nix 四卷），先把 /persist 备份出去
#
# 首次安装（手工，仓库须在 /mnt/persist/etc/nixos）：
#   sgdisk -n 6:220GiB:+1GiB -t 6:EF00 -c 6:NIXOS-ESP /dev/nvme0n1
#   sgdisk -n 7:221GiB:+16GiB -t 7:8200 -c 7:NIXOS-SWAP /dev/nvme0n1
#   sgdisk -n 8:0:0 -t 8:8300 -c 8:NIXOS-POOL /dev/nvme0n1
#   mkfs.vfat -F32 -n NIXOS-ESP /dev/nvme0n1p6
#   mkswap -L NIXOS-SWAP /dev/nvme0n1p7
#   mkfs.btrfs -f -L nixos /dev/nvme0n1p8
#   mount /dev/nvme0n1p8 /mnt && for s in @root @boot @persist @nix; do btrfs subvolume create /mnt/$s; done && umount /mnt
{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-partlabel/NIXOS-POOL";
      fsType = "btrfs";
      options = [
        "subvol=@root"
        "compress=zstd"
        "noatime"
      ];
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/NIXOS-POOL";
      fsType = "btrfs";
      options = [
        "subvol=@boot"
        "noatime"
      ];
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
      device = "/dev/disk/by-partlabel/NIXOS-POOL";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd"
        "noatime"
      ];
    };
    "/persist" = {
      device = "/dev/disk/by-partlabel/NIXOS-POOL";
      fsType = "btrfs";
      options = [
        "subvol=@persist"
        "compress=zstd"
        "noatime"
      ];
      neededForBoot = true;
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-partlabel/NIXOS-SWAP"; }
  ];
}
