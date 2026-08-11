# 登录后桌面会话管理器（当前为 Quartz/Aqua）
# 自动扫描导入 quartz/ 目录下所有功能模块
{ tools, ... }:
{
  imports = tools.scan ./.;
}
