# ds2（10.2.241.104，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：zfs_arc_max（zfs 缓存上限 3.1G）；公共 nvidiafb 见 common
# 注意：modprobeHost 键含点必须引号
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  ip = "10.2.241.104/24";                        # 静态 IP（apply 写 vmbr0）
  gateway = "10.2.241.254";
  modprobeHost = {
    "intel-microcode-blacklist.conf" = "blacklist microcode";
    "zfs.conf" = "options zfs zfs_arc_max=3341811712";
  };
in
{
  inherit (common) dns mirror pveAssistBase modprobePublic;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline;
  inherit modprobeHost;
  inherit ip gateway;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
    modprobePublic = common.modprobePublic;
    inherit modprobeHost;
    inherit ip gateway;
  };
}
