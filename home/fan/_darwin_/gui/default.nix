# macOS GUI 应用配置
# 自动扫描导入
{ tools, ... }:
{
  imports = tools.scan ./.;
}
