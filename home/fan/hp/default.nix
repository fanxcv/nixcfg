# hp（10.2.237.149，HP ProBook 450 G10 笔记本，PVE 9.0.11 宿主机）—— home 层机器微调（HM standalone，root 用户）
# 组装：_common_（跨平台）+ _pve_（PVE 平台层）+ 本机微调
# 系统层（apt 源/DNS/去 nag/pve-assist/lid ignore/tailscaled unit）见 pve/hp/，部署：nix run .#hp
# tailscale：nix 包（HM profile），state 全新需手动 tailscale up 认证
{ tools, pkgs, ... }:
{
  imports = [ ../_common_ ../_pve_ ] ++ tools.scan ./.;
  home.packages = [ pkgs.tailscale ];
}
