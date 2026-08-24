# desktop（10.2.241.208，PVE 9.x 宿主机，N100 迷你机）—— home 层机器微调（HM standalone，root 用户）
# 组装：_common_（跨平台）+ _pve_（PVE 平台层）+ 本机微调
# 系统层（apt 源/DNS/去 nag/pve-assist）见 pve/desktop/，部署：nix run .#desktop
{ tools, ... }:
{
  imports = [ ../_common_ ../_pve_ ] ++ tools.scan ./.;
}
