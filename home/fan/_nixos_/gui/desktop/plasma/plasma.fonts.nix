# Plasma 字体：跟随 fontconfig 默认（Noto CJK + Monaspace 等宽），统一 10pt（tsln 同款）
{ lib, config, ... }:
let
  inherit (config.fonts.fontconfig) defaultFonts;
in
{
  programs.plasma.fonts = {
    general = {
      family = lib.head defaultFonts.sansSerif;
      pointSize = 10;
    };
    fixedWidth = {
      family = lib.head defaultFonts.monospace;
      pointSize = 10;
    };
    toolbar = {
      family = lib.head defaultFonts.sansSerif;
      pointSize = 10;
    };
    menu = {
      family = lib.head defaultFonts.sansSerif;
      pointSize = 10;
    };
    small = {
      family = lib.head defaultFonts.sansSerif;
      pointSize = 8;
    };
    windowTitle = {
      family = lib.head defaultFonts.sansSerif;
      pointSize = 10;
    };
  };
}
