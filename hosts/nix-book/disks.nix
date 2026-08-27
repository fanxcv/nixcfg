# 声明式磁盘（disko）：476.9G NVMe 全盘格，LVM 布局 + tmpfs 根（不可变系统）
#   EFI 512M + LVM（boot 1G + swap 8G + persist 100G + nix 100G），LVM 余量 ~267G（lvextend 可扩 nix/persist）
#   swap 8G 供 hibernate（tsln 电源计划 criticalAction=hibernate 需要；zram 是压缩内存不可休眠）
# 首次安装：nix run nixpkgs#disko -- --mode disko ./hosts/nix-book/disks.nix
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
          size = "8G";
          content = {
            type = "swap";
            resumeDevice = true; # hibernate 恢复目标
          };
        };
        persist = {
          size = "100G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
          };
        };
        nix = {
          size = "100G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
          };
        };
      };
    };
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=2G"
          "mode=0755"
        ];
      };
      "/tmp" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=2G"
        ];
      };
    };
  };
}
