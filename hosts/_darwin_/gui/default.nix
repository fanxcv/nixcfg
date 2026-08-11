# macOS GUI 层（登录前显示管理器 + 登录后桌面会话）
# 自动扫描导入：新增模块文件即生效

{ tools, ... }:
{
  imports = tools.scan ./.;
}
