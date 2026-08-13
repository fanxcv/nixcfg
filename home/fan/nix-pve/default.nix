# nix-pve（PVE 虚拟机）—— home 层机器微调（home-manager 内嵌于 NixOS，本文件是唯一入口）
# 组装：_common_（跨平台共享）+ _nixos_（Linux/NixOS 平台层）+ 本机微调
{ tools, ... }:
{
  imports = [
    ../_common_
    ../_nixos_
  ] ++ (tools.scan ./.);
}
