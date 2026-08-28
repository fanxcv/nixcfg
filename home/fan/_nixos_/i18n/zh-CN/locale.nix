# 语言环境：基础语言 en_US（终端/SSH 保持英文输出）；KDE 界面中文声明式写入
# （plasma-localerc.nix 的 configFile."plasma-localerc" 管 [Translations] Language=zh_CN，不随 LANG 变化）
{ lib, ... }:
{
  home.language.base = lib.mkDefault "en_US.UTF-8";
}
