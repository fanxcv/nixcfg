# MacBook Air（M5）—— 机器差异层（公共组装见 hosts/_darwin_/default.nix）
{ tools, ... }:
{
  imports = tools.scan ./.;
}
