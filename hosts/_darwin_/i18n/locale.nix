# 语言环境（系统级，所有 Mac）：中文界面 + 中文系统语言
# 语言环境：GUI 界面中文（AppleLocale/AppleLanguages），环境变量用英文（SSH 到 Linux 服务器不触发中文 locale 问题）
# 用户层 home.language.base 见 home/fan/_darwin_/i18n/zh-CN/locale.nix
{
  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    AppleLocale = "zh_CN";
    AppleLanguages = [
      "zh-Hans-CN"
      "en-CN"
    ];
  };
}
