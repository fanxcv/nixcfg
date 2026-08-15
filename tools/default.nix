# 工具集合（flake.nix 注入 specialArgs.tools，模块里用 { tools, ... } 取用）
{ lib, self }:
let
  # GitHub 加速前缀（换代理：改 github-proxy.nix + 跑 scripts/switch-github-proxy.sh 同步 inputs/lock）
  githubProxy = import ./github-proxy.nix;
in
{
  inherit githubProxy;
  scan = import ./scan.nix { inherit lib; };
  relative = import ./relative.nix { inherit self; };
}
