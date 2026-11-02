# 根跑在 btrfs 子卷上时的「开机擦根」：initrd 里把旧子卷改名成快照、建空子卷，
# 得到与 tmpfs 根等效的干净根，但落盘（不受 RAM 大小限制），且旧根可回滚。
#
# 为何要在 initrd：根一旦挂上就不能再换，必须抢在 sysroot.mount 之前。
# 为何按份数保留而非按天数：笔记本开机不规律，"30 天内"可能只有一两份也可能几十份，
# 按份数才能给根子卷一个可预测的空间上界。
#
# 已知坑（都已在下面处理）：
#   - initrd 没有 btrfs CLI（nixpkgs 只给 coreutils + systemd + mount/umount/fsck），须 extraBin；
#   - 删除失败不能中止脚本（NixOS 用 set -e 包裹 script），否则空根建不出来 → 开不了机，
#     故先建空根、再清理，且清理失败只告警；
#   - 休眠恢复（systemd-hibernate-resume 直接恢复内存镜像）后不应再擦根，用 after 排序规避。
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixcfg.rootOnBtrfs;
in
{
  options.nixcfg.rootOnBtrfs = {
    enable = lib.mkEnableOption "btrfs 子卷作根 + initrd 开机擦根";
    device = lib.mkOption {
      type = lib.types.str;
      example = "/dev/pool/root";
      description = "根所在 btrfs 的整卷设备（非子卷路径）；脚本以 subvolid=5 挂它来找子卷";
    };
    subvolume = lib.mkOption {
      type = lib.types.str;
      default = "@root";
      description = "挂到 / 的子卷名";
    };
    snapshotKeep = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "保留最近几份旧根快照（删除更早的），决定快照占用的空间上界";
    };
  };

  config = lib.mkIf cfg.enable {
    # btrfs-progs 不在 initrd 默认集合里，不补则脚本第一句就 command not found
    boot.initrd.systemd.extraBin.btrfs = "${pkgs.btrfs-progs}/bin/btrfs";

    boot.initrd.systemd.services.btrfs-wipe-root = {
      description = "擦根：旧 ${cfg.subvolume} 转快照后重建空子卷";
      unitConfig.DefaultDependencies = false;
      wantedBy = [ "initrd.target" ];
      # 必须在挂根之前；休眠恢复成功时系统直接回到内存镜像，本单元不再执行
      before = [ "sysroot.mount" ];
      after = [ "systemd-hibernate-resume.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mnt=/btrfs-root
        snaps="$mnt/.snapshots/${cfg.subvolume}"
        mkdir -p "$snaps"

        # 设备节点可能比本单元晚出现（udev / LVM 激活），最多重试 5 秒
        mounted=
        for _ in $(seq 1 50); do
          if mount -o subvolid=5 ${cfg.device} "$mnt" 2>/dev/null; then
            mounted=1
            break
          fi
          sleep 0.1
        done
        if [ -z "$mounted" ]; then
          echo "警告: 挂不上 ${cfg.device}，本次不擦根（根保持上次内容）"
          exit 1
        fi
        trap 'umount "$mnt"' EXIT

        # 旧根转快照（这就是回滚点）
        if [ -e "$mnt/${cfg.subvolume}" ]; then
          mv "$mnt/${cfg.subvolume}" "$snaps/$(date +%Y%m%d%H%M%S)"
        fi

        # 先建空根：即使下面的清理失败也必须能开机
        btrfs subvolume create "$mnt/${cfg.subvolume}"

        # 只留最近 ${toString cfg.snapshotKeep} 份；删除失败只告警
        for old in $(ls -1 "$snaps" 2>/dev/null | sort | head -n -${toString cfg.snapshotKeep}); do
          btrfs subvolume delete --recursive "$snaps/$old" \
            || echo "警告: 删除旧根快照 $old 失败"
        done
      '';
    };

    # initrd 擦根静默失效（缺命令/挂载失败）时根会悄悄变回持久，这里每开机自检一次并喊出来（以根子卷创建时间为准）
    systemd.services.nixcfg-root-wipe-check = {
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        created=$(
          ${pkgs.btrfs-progs}/bin/btrfs subvolume show / 2>/dev/null \
            | ${pkgs.gnused}/bin/sed -n 's/^[[:space:]]*Creation time:[[:space:]]*//p'
        )
        case "$created" in
          "$(${pkgs.coreutils}/bin/date +%Y-%m-%d)"*)
            echo "擦根成功：/ 创建于 $created（本次开机）"
            ;;
          "")
            echo "警告: 读不到根子卷创建时间（/ 不是 btrfs 子卷？），无法确认擦根" >&2
            ;;
          *)
            echo "警告: 根子卷创建于 $created，不是本次开机 → initrd 的 btrfs-wipe-root 未生效，根仍是旧内容" >&2
            ;;
        esac
      '';
    };
  };
}
