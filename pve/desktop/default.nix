# desktop（10.2.241.208，PVE 9.x 宿主机，Debian 13 trixie）系统层定义
# N100 迷你主机：vfio 直通核显（8086:3185）+ zfs arc 限制在 /etc/modprobe.d/（机器专属，apply 不触碰）
# 公共参数（DNS/mirror/grubCmdline）来自 pve/default.nix
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
in
{
  inherit (common) dns mirror pveAssistBase;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline;             # 公共：quiet consoleblank=60 intel_iommu=on iommu=pt
  files = import ../render.nix {
    inherit pkgs lib;
    dns = common.dns;
    mirror = common.mirror;
    suite = "trixie";
    grubCmdline = common.grubCmdline;
  };
}
