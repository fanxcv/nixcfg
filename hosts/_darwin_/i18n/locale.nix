# 语言环境（系统级，所有 Mac）：LANG/LC_ALL = en_US.UTF-8
# launchctl setenv 写入全局环境（shell + GUI 应用都继承）
# 用户层 home.language.base 见 home/fan/_darwin_/i18n/zh-CN/locale.nix
{
  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };
}
