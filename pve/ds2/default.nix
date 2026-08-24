# ds2（PVE 9.2 宿主机，Debian 13 trixie）系统层定义
# 公共参数（DNS/mirror/grubCmdline）来自 pve/default.nix；渲染见 pve/render.nix
# 机器专属（如 GRUB 直通参数）在此追加到 grubCmdline
{ pkgs, lib, ... }:
let
  common = import ../default.nix;
in
{
  inherit (common) dns mirror pveAssistBase;
  suite = "trixie";                              # PVE 9 = Debian 13
  grubCmdline = common.grubCmdline;             # 公共：quiet consoleblank=60 intel_iommu=on iommu=pt
  files = import ../render.nix { inherit pkgs lib; dns = common.dns; mirror = common.mirror; suite = "trixie"; grubCmdline = common.grubCmdline; };
}
