# hp（10.2.237.149，HP ProBook 450 G10）—— home 层当前无机器差异。
# 公共/平台层由 home/fan/module-list.nix 注入；系统层见 pve/hp/。
{ tools, ... }:
{
  imports = tools.scan ./.;
}
