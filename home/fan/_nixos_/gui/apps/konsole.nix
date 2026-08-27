# Konsole 终端：Catppuccin mocha 配色（主题由 modules/home/catppuccin/konsole.nix 接管，
# 见 ../../themes/catppuccin.nix 的 konsole.enable/flavor）；此处只管 Konsole 本体设置（tsln 同款）
{ lib, config, ... }:
let
  inherit (config.fonts.fontconfig) defaultFonts;
in
{
  programs.konsole = {
    enable = true;
    defaultProfile = "Default";

    ui.colorScheme = "BreezeDark";

    extraConfig = {
      MainWindow.MenuBar = "Enabled";
    };

    profiles.Default = {
      font = {
        name = lib.head defaultFonts.monospace;
        size = 11;
      };
    };
  };
}
