# ds2（PVE 9.2 宿主机，Debian 13 trixie）—— home 层当前无机器差异。
# 公共/平台层由 home/fan/module-list.nix 注入；系统层见 pve/ds2/。
{ tools, ... }:
{
  imports = tools.scan ./.;
}
