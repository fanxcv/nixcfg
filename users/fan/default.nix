# 用户定义（对应原仓库 users/tsln）
# darwin：primaryUser + home-manager 内嵌（home-manager.users.fan = home/fan/<hostName>）
# Linux（NixOS 真机）分支待接入时补充：isNormalUser / extraGroups / hashedPassword

{
  lib,
  tools,
  config,
  ...
}:
let
  inherit (config.networking) hostName;
  inherit (lib.strings) toLower;
  userName = "fan";
in
{
  # User primary（darwin 系统层用：homebrew user、screencapture 路径等）
  system.primaryUser = lib.mkForce userName;

  # Home Manager 内嵌于 nix-darwin：用户配置 = home/fan/<hostName>/（组装清单见该目录）
  home-manager.users."${userName}" = tools.relative "home/fan/${toLower hostName}";
}
