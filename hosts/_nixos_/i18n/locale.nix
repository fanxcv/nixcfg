# 系统 locale：默认 zh_CN（SDDM 登录界面/系统服务中文；用户终端 LANG 由 home.language.base 决定，保持 en_US）
{
  lib,
  pkgs,
  config,
  ...
}:
{
  i18n.defaultLocale = lib.mkDefault "zh_CN.UTF-8";
  i18n.supportedLocales = lib.mkDefault [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];
  i18n.glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = config.i18n.supportedLocales;
  };
}
