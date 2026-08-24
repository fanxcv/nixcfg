# razer（10.2.241.80，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属 GRUB：N 卡直通（GTX 1660 Ti Mobile / 10de:2191）——initcall_blacklist=sysfb_init
# + pcie_acs_override=downstream + video=vesafb:off,efifb:off；modprobe（nvidia/nouveau 黑名单）为机器现状，apply 不触碰
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
  extra = [ "initcall_blacklist=sysfb_init" "pcie_acs_override=downstream" "video=vesafb:off" "video=efifb:off" ];
in
{
  inherit (common) dns mirror pveAssistBase;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline ++ extra;
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline ++ extra;
  };
}
