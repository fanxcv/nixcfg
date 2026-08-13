# 声明式磁盘（disko）：128G 虚拟盘，LVM 布局 + tmpfs 根（不可变系统）
#   boot 1G + persist 40G + nix 48G，LVM 余量 ~39G（lvextend 可扩 nix/persist）
# 首次安装：nix run nixpkgs#disko -- --mode disko ./hosts/nix-pve/disks.nix
#   （PVE 磁盘类型：virtio-scsi → /dev/sda；virtio-blk → /dev/vda，按实际调整）
_: {
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/vda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "200M";
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
        persist = {
          size = "40G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
          };
        };
        nix = {
          size = "48G";
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
