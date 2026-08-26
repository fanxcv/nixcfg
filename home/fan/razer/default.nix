# razer（10.2.241.80，PVE 9.2 宿主机）—— home 层当前无机器差异。
# 公共/平台层由 home/fan/module-list.nix 注入；系统层见 pve/razer/。
{ tools, ... }:
{
  imports = tools.scan ./.;
}
