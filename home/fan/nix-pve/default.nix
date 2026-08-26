# nix-pve 用户层机器微调；公共/平台层由 home/fan/module-list.nix 注入。
{ tools, ... }:
{
  imports = tools.scan ./.;
}
