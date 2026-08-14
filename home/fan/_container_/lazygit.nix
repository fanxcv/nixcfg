# lazygit（终端 Git UI）——参考 tsln1998/nixcfg 的 home/tsln/_common_/dev/programs/lazygit.nix
# tsln 版本另带 pkgs.gitflow；按需求只装 lazygit（gitflow 用不到不带）
{ pkgs, ... }:
{
  programs.lazygit.enable = true;
}
