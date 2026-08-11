# 工具集合（flake.nix 注入 specialArgs.tools，模块里用 { tools, ... } 取用）
{ lib, self }:
{
  scan = import ./scan.nix { inherit lib; };
  relative = import ./relative.nix { inherit self; };
}
