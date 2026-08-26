# 用户定义（对应原仓库 users/tsln）
# darwin / NixOS：系统用户定义 + Home Manager 内嵌（模块清单复用 home/fan/module-list.nix）
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
  # 用户配置由 home/fan/module-list.nix 统一组装（_common_ + 平台层 + 可选机器差异）。
  # 复用系统 pkgs（allowUnfreePredicate 一并生效，见 flake.nix）
  home-manager.useGlobalPkgs = true;
  # home-manager 的 user submodule 不继承系统层 specialArgs，
  # 必须注入顶层 extraSpecialArgs（tools.scan / ${self} 主题路径 / inputs 都要用）
  home-manager.extraSpecialArgs = {
    inherit
      self
      inputs
      outputs
      tools
      useChinaMirror
      isContainer
      platform
      hostName
      ;
  };

  # 用户配置统一由 home/fan/module-list.nix 组装，避免每台机器重复导入公共/平台层。
  home-manager.users."${userName}" = {
    imports = [
      (self + "/home/fan")
    ]
    ++ import (self + "/home/fan/module-list.nix") {
      inherit
        lib
        self
        platform
        hostName
        ;
    };
  };
}
