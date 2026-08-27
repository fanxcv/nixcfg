# Catppuccin 壁纸（上游 catppuccin/nix 无 wallpaper target，自封装，tsln 同款）
# 桌面 + 锁屏同款壁纸（nixos-artwork 自带，按 flavor 取）
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.catppuccin.wallpaper;
  enable = cfg.enable && config.catppuccin.enable && config.programs.plasma.enable;
  artwork = pkgs.nixos-artwork.wallpapers."catppuccin-${cfg.flavor}";
  wallpaper = "${artwork}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-${cfg.flavor}.png";
in
{
  options.catppuccin.wallpaper = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.catppuccin.autoEnable;
      description = "Enable Catppuccin wallpaper (desktop + lockscreen)";
    };

    flavor = lib.mkOption {
      type = lib.types.str;
      default = config.catppuccin.flavor;
      description = "Catppuccin flavor";
    };
  };

  config = lib.mkIf enable {
    programs.plasma.workspace = {
      inherit wallpaper;
    };

    programs.plasma.kscreenlocker.appearance = {
      inherit wallpaper;
    };
  };
}
