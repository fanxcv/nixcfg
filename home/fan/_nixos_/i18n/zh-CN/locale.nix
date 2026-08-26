# 语言环境：基础语言 en_US（终端/SSH 保持英文输出）；KDE 界面中文由 plasma-localerc 声明式写入
# （KDE 界面语言读 plasma-localerc 的 [Translations]，不随 LANG 变化——LANG 只影响非 KDE 应用）
{ lib, ... }:
{
  home.language.base = lib.mkDefault "en_US.UTF-8";

  # KDE 界面语言：声明式写 plasma-localerc（KDE 启动时读；用户改语言设置会被下次激活覆盖，声明式优先）
  # 注意：KDE 会话运行中改此文件不生效，需注销重登（或重启 plasmashell）
  home.file.".config/plasma-localerc".text = ''
    [Formats]
    LANG=zh_CN.UTF-8

    [Translations]
    LANGUAGE=zh_CN
    Language=zh_CN
  '';
}
