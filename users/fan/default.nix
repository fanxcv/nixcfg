# 用户定义（对应原仓库 users/tsln）
# darwin：primaryUser + home-manager 内嵌（home-manager.users.fan = home/fan/<hostName>）
# Linux（NixOS 真机）分支待接入时补充：isNormalUser / extraGroups / hashedPassword

{
  lib,
  self,
  inputs,
  outputs,
  tools,
  useChinaMirror,
  isContainer,
  platform,
  config,
  ...
}:
let
  inherit (config.networking) hostName;
  inherit (lib.strings) toLower;
  userName = "fan";
in
{
  # darwin 系统用户定义（home-manager 集成的 common.nix 会读 name/home/uid）
  users.users.fan = {
    name = "fan";
    home = "/Users/fan";
    shell = "/bin/zsh";
  };

  # User primary（darwin 系统层用：homebrew user、screencapture 路径等）
  system.primaryUser = lib.mkForce userName;

  # Home Manager 内嵌于 nix-darwin：用户配置 = home/fan/<hostName>/（组装清单见该目录）
  # 复用系统 pkgs（claudeOverlay + allowUnfreePredicate 一并生效，见 flake.nix mkDarwinConfig）
  home-manager.useGlobalPkgs = true;
  # home-manager 的 user submodule 不继承 nix-darwin 的 specialArgs，
  # 必须注入顶层 extraSpecialArgs（tools.scan / ${self} 主题路径 / inputs 都要用）
  home-manager.extraSpecialArgs = {
    inherit self inputs outputs tools useChinaMirror isContainer platform;
  };

  home-manager.users."${userName}" = tools.relative "home/fan/${toLower hostName}";
}
