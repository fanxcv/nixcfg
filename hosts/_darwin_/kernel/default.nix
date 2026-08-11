# Darwin 内核/底层系统模块
# 自动扫描导入：新增 .nix 文件即生效
{ tools, ... }:
{
  imports = tools.scan ./.;
}
