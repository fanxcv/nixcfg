# 声明式磁盘（disko）：953.9G NVMe 全盘格，LVM 布局 + btrfs 根子卷（不可变系统）
#   EFI 512M + LVM（root 40G + boot 1G + swap 32G + persist 400G + nix 300G），LVM 余量 ~180G（lvextend 可扩 nix/persist）
#   根是 btrfs 子卷 @root（zstd 压缩、落盘，不受 RAM 限制）：每次开机 initrd 把旧根改名为快照再
#   建空子卷（hosts/_nixos_/base/root-on-btrfs.nix），保留最近 3 份供回滚
#   persist 2026-10-10 由 200G 扩至 400G（Switch ROM 库，~/roms → /persist/home/fan/roms）；
#   扩容是在线 lvextend + resize2fs 做的（disko 不在运行时改布局），此处改 size 只为声明与实际一致
#   swap 32G 供 hibernate（27G 内存，tsln 电源计划 criticalAction=hibernate 需要；zram 是压缩内存不可休眠）
# 首次安装：nix run nixpkgs#disko -- --mode disko ./hosts/nix-lenovo/disks.nix
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
          lvm = {
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };
    lvm_vg.pool = {
      type = "lvm_vg";
      lvs = {
        boot = {
          size = "1G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/boot";
          };
        };
        swap = {
          size = "32G";
          content = {
            type = "swap";
            resumeDevice = true; # hibernate 恢复目标
          };
        };
        persist = {
          size = "400G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
          };
        };
        nix = {
          size = "300G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
          };
        };
        root = {
          size = "40G";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "nixroot"
            ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
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
}
