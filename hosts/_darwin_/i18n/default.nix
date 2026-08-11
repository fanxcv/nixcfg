# macOS i18n（系统字体等）
# 自动扫描导入
{ tools, ... }:
{
  imports = tools.scan ./.;
}
