# 声明式磁盘（disko）：953.9G NVMe，单 btrfs 池 + 子卷（不可变系统）
#   GPT：EFI 512M + swap 32G + btrfs 640G + 盘尾 ~280G 空闲
#   （nix-lenovo 实盘上该空闲区已建为 p4，留给 Windows 双系统；本文件不声明它）
#     @root → /      @boot → /boot      @persist → /persist      @nix → /nix
#   根是 @root（zstd 压缩、落盘，不受 RAM 限制）：每次开机 initrd 把旧根改名为快照再
#   建空子卷（hosts/_nixos_/base/root-on-btrfs.nix），保留最近 3 份供回滚
#   swap 单列分区（不进 btrfs）：休眠恢复要连续块设备，swapfile 得手算 resume_offset，不值当
#   @boot 不压缩：GRUB 从 btrfs+zstd 读内核是少见路径，省那点空间不如省事
# ⚠ 空间耦合：单池下 /persist 写爆会连带打穿 /nix 与根，这是共享空间的代价
# ⚠ 全盘格式化：本文件 --mode disko 会 sgdisk --clear 抹整盘（含 p4 Windows 区），改造前先把 /persist 与 Windows 数据备份出去；
#   已装 Windows 后重装 NixOS 用 --mode format,mount，不重建分区表
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
          swap = {
            size = "32G";
            content = {
              type = "swap";
              resumeDevice = true; # hibernate 恢复目标（27G 内存）
            };
          };
          pool = {
            # 固定 640G，不取 100%：盘尾约 280G 留作独立分区 p4（Windows 用），
            # 取 100% 则 disko 重建时会把该空隙并进池，将来想切回来还得手工分区。
            # ⚠ 仍需知：disko --mode disko 开头就 sgdisk --clear 整盘，p4 数据必没。
            #   装过 Windows 后重装 NixOS 须用 `--mode format,mount`（保留分区表，只重格 p1–p3）。
            size = "640G";
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
