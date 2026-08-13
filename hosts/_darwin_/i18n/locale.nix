# 语言环境（系统级，所有 Mac）：中文界面 + 中文系统语言
# LANG/LC_ALL 写入全局环境；AppleLocale/AppleLanguages 决定 GUI 界面语言
# 用户层 home.language.base 见 home/fan/_darwin_/i18n/zh-CN/locale.nix
{
  environment.variables = {
    LANG = "zh_CN.UTF-8";
    LC_ALL = "zh_CN.UTF-8";
  };

  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    AppleLocale = "zh_CN";
    AppleLanguages = [ "zh-Hans-CN" "en-CN" ];
  };
}
