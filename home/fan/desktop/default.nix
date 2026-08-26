# desktop（10.2.241.208，PVE 9.x 宿主机）—— home 层当前无机器差异。
# 公共/平台层由 home/fan/module-list.nix 注入；系统层见 pve/desktop/。
{ tools, ... }:
{
  imports = tools.scan ./.;
}
