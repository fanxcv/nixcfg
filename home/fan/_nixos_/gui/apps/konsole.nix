# Konsole 终端：配色用 BreezeDark（catppuccin konsole 随主题启用——见 themes/catppuccin.nix，装 catppuccin-konsole 配色包，仅预设不强制切）；此处只管 Konsole 本体设置（tsln 同款全量）
# General.ConfigVersion = 1 不可省：缺此键 Konsole 启动时按旧版迁移重写 konsolerc，nix 写入的设置被抹（tsln 40e3259c）
# 工具栏不在此文件：无配置项，走 overlays/konsole.nix 的 --hide-toolbars 启动参数
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
      General.ConfigVersion = 1;
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
