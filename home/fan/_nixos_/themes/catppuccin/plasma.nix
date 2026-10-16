# Catppuccin Plasma 桌面主题（上游 catppuccin/nix 无 plasma target，自封装，tsln 同款）
# 配色方案 + 开机画面 + 光标（colorScheme/splashScreen/cursor）
{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib.strings) toSentenceCase;
  cfg = config.catppuccin.plasma;
  enable = cfg.enable && config.catppuccin.enable && config.programs.plasma.enable;
in
{
  options.catppuccin.plasma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.catppuccin.autoEnable;
      description = "Enable Catppuccin for Plasma";
    };

    flavor = lib.mkOption {
      type = lib.types.str;
      default = config.catppuccin.flavor;
      description = "Catppuccin flavor";
    };

    accent = lib.mkOption {
      type = lib.types.str;
      default = config.catppuccin.accent;
      description = "Catppuccin accent";
    };
  };

  config = lib.mkIf enable {
    # Catppuccin Plasma 主题包（nixpkgs 自带）
    home.packages = [
      (pkgs.catppuccin-kde.override {
        flavour = [ cfg.flavor ];
        accents = [ cfg.accent ];
      })
    ];

    # 配色方案 / 开机画面 / 光标
    programs.plasma.workspace = {
      colorScheme = "Catppuccin${toSentenceCase cfg.flavor}${toSentenceCase cfg.accent}";

      splashScreen.theme = "Catppuccin-${toSentenceCase cfg.flavor}-${toSentenceCase cfg.accent}";

      cursor.theme = if cfg.flavor == "latte" then "Breeze_Light" else "breeze_cursors";
    };
  };
}
