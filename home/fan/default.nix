# home-manager 入口（所有机器共用）
# 平台模块（_nixos_/_darwin_）和机器模块（<host>）由 flake.nix 按机器注入
# 结构参考 nixcfg 的 home/tsln：_common_（跨平台）+ _nixos_/_darwin_（平台）+ <host>（机器）

# 用户身份：平台规则 nixos/darwin=fan、alpine=root（alpine-init.sh 是 root 语义）
# 机器可覆盖：ide 容器挂载/SSH 全是 /root，在 ../ide/default.nix mkForce 回 root

{ pkgs, platform ? "nixos", ... }:
{
  imports = [ ./_common_ ];

  home.username = if platform == "alpine" then "root" else "fan";
  home.homeDirectory =
    if platform == "alpine" then "/root"
    else if pkgs.stdenv.isDarwin then "/Users/fan"
    else "/home/fan";
  home.stateVersion = "25.05";

  # 让 home-manager 命令本身可用（以后可以直接 home-manager switch）
  programs.home-manager.enable = true;
}
