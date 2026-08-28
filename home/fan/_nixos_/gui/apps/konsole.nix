# Konsole 终端：配色用 BreezeDark（catppuccin konsole 已随主题切换禁用，见 themes/catppuccin.nix）；此处只管 Konsole 本体设置（tsln 同款）
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
