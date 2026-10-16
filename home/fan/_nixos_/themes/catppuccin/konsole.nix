# Catppuccin Konsole 终端主题（上游 catppuccin/nix 无 konsole target，自封装，tsln 同款）
# 配色文件自打包（packages/catppuccin/konsole.nix → overlay 的 pkgs.catppuccin-konsole）
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.catppuccin.konsole;
  enable = cfg.enable && config.catppuccin.enable && config.programs.konsole.enable;
in
{
  options.catppuccin.konsole = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.catppuccin.autoEnable;
      description = "Enable Catppuccin for Konsole";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.catppuccin-konsole;
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
    # 配色文件软链到 ~/.local/share/konsole/
    home.file.".local/share/konsole/catppuccin-${cfg.flavor}.colorscheme".source =
      "${cfg.package}/catppuccin-${cfg.flavor}.colorscheme";

    # 默认 profile 套用 Catppuccin 配色
    programs.konsole.profiles."${config.programs.konsole.defaultProfile}".colorScheme =
      "catppuccin-${cfg.flavor}";
  };
}
