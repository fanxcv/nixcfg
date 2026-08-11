# 语言环境：基础语言 en_US（中文显示由应用层字体/输入法处理）
{ lib, ... }:
{
  home.language.base = lib.mkDefault "en_US.UTF-8";
}
