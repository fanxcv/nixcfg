# fan（10.2.241.88，PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 机器专属：GRUB video=efifb:off,vesafb:off（核显直通，Iris Plus 655 / 8086:3ea5）
# modprobe（kvm ignore_msrs / vfio 直通 / 声卡黑名单）为机器现状，apply 不触碰
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
in
{
  inherit (common) dns mirror pveAssistBase;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline ++ [ "video=efifb:off,vesafb:off" ];
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline ++ [ "video=efifb:off,vesafb:off" ];
  };
}
