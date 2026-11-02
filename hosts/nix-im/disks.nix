# 声明式磁盘（disko）：953.9G NVMe 全盘格，单 btrfs 池 + 子卷（不可变系统）
#   布局与 nix-lenovo 逐字一致（同容量 953.9G NVMe），差异只在机器身份与硬件层
#   GPT：EFI 512M + swap 32G + btrfs 剩余（~921G），四个子卷共享空间，不再有定长卷
#     @root → /      @boot → /boot      @persist → /persist      @nix → /nix
#   根是 @root（zstd 压缩、落盘）：每次开机 initrd 擦根并保留最近 3 份快照，见
#   hosts/_nixos_/base/root-on-btrfs.nix
#   swap 单列分区（不进 btrfs）：休眠恢复要连续块设备；32G ≥ 30G 内存，hibernate 才可靠
#   @boot 不压缩：GRUB 从 btrfs+zstd 读内核是少见路径
# ⚠ 空间耦合：单池下 /persist 写爆会连带打穿 /nix 与根
# ⚠ 全盘格式化：本文件 --mode disko 会抹掉整盘（含原有 Windows/BitLocker 分区）
# 首次安装：nix run nixpkgs#disko -- --mode disko ./hosts/nix-im/disks.nix
#   （NVMe → /dev/nvme0n1；安装镜像 U 盘是 /dev/sda，勿混淆）
_: {
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountOptions = [
                "defaults"
                "umask=0077"
              ];
              mountpoint = "/boot/efi";
            };
          };
          swap = {
            size = "32G";
            content = {
              type = "swap";
              resumeDevice = true; # hibernate 恢复目标（30G 内存）
            };
          };
          pool = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [
                "-f"
                "-L"
                "nixos"
              ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@boot" = {
                  mountpoint = "/boot";
                  mountOptions = [ "noatime" ];
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
