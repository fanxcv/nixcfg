# 系统 locale：默认 en_US（与 mac 一致），支持中文（fcitx5 输入法 + Noto CJK 字体）
{
  lib,
  pkgs,
  config,
  ...
}:
{
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.supportedLocales = lib.mkDefault [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];
  i18n.glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = config.i18n.supportedLocales;
  };
}
