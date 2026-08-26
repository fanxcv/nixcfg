# 用户定义（对应原仓库 users/tsln）
# darwin：primaryUser + home-manager 内嵌（home-manager.users.fan = home/fan/<hostName>）
# NixOS 真机（nix-pve）：isNormalUser + 组授权 + home-manager 挂载（home/fan/<hostName>）
#   密码策略：不内置 hash（SSH 公钥登录由 _common_/ssh.nix 激活拉取；
#   控制台登录需接入时设置，hash 可后续走 agenix）

{
  lib,
  pkgs,
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
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
  inherit (config.networking) hostName;
  inherit (lib.strings) toLower;
  userName = "fan";
  isNixos = platform == "nixos";
in
{
  # 系统用户定义（platform 分支：darwin 用 name/home/shell，NixOS 用 isNormalUser + 组）
  users.users."${userName}" =
    (lib.optionalAttrs isNixos {
      isNormalUser = true;
      extraGroups = builtins.filter (g: builtins.hasAttr g config.users.groups) [
        "wheel"
        "podman"
        "networkmanager"
      ];
    })
    // (lib.optionalAttrs isDarwin {
      name = userName;
      home = "/Users/${userName}";
      shell = "/bin/zsh";
    })
    // (lib.optionalAttrs isNixos {
      shell = "${pkgs.zsh}/bin/zsh"; # NixOS 无 /bin，必须 store 路径
      # 登录密码 hash 走 agenix（secrets/hosts/nix-pve/fan-password.age，见 hosts/_nixos_/base/password.nix）；
      # SSH 登录走公钥（home 层 ssh.nix 拉取），密码仅 SDDM 图形登录用
      hashedPasswordFile = config.age.secrets."fan-password".path;
    });

  # User primary（darwin 系统层用：homebrew user、screencapture 路径等；NixOS 无此选项）
  system = lib.optionalAttrs isDarwin {
    primaryUser = lib.mkForce userName;
  };

  # Home Manager 内嵌：darwin 挂 nix-darwin 的 home-manager 模块，NixOS 挂 home-manager.nixosModules
  # 用户配置 = home/fan/<hostName>/（组装清单见该目录）
  # 复用系统 pkgs（allowUnfreePredicate 一并生效，见 flake.nix）
  home-manager.useGlobalPkgs = true;
  # home-manager 的 user submodule 不继承系统层 specialArgs，
  # 必须注入顶层 extraSpecialArgs（tools.scan / ${self} 主题路径 / inputs 都要用）
  home-manager.extraSpecialArgs = {
    inherit self inputs outputs tools useChinaMirror isContainer platform hostName;
  };

  home-manager.users."${userName}" = tools.relative "home/fan/${toLower hostName}";
}
