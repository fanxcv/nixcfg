# razer（10.2.241.80，PVE 9.2 宿主机）—— home 层机器微调（HM standalone，root 用户）
# 组装：_common_（跨平台）+ _pve_（PVE 平台层）+ 本机微调
# 系统层（apt 源/DNS/去 nag/pve-assist）见 pve/razer/，部署：nix run .#razer
{ tools, ... }:
{
  imports = [ ../_common_ ../_pve_ ] ++ tools.scan ./.;
}
