# macOS 系统服务（三台公共）
# 自动扫描导入
{ tools, ... }:
{
  imports = tools.scan ./.;
}
