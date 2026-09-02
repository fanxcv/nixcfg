# Konsole 终端：配色用 BreezeDark（catppuccin konsole 随主题启用——见 themes/catppuccin.nix，装 catppuccin-konsole 配色包，仅预设不强制切）；此处只管 Konsole 本体设置（tsln 同款）
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
