# mbp-m1 用户配置（home-manager，内嵌于 nix-darwin）
{ tools, ... }:
{
  imports = [
    ../_common_
    ../_darwin_
  ] ++ (tools.scan ./.);
}
