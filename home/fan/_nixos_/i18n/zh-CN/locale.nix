# 语言环境：基础语言 en_US（与 mac 一致；中文由输入法/字体处理）
{ lib, ... }:
{
  home.language.base = lib.mkDefault "en_US.UTF-8";
}
