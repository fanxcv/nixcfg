# 机器专属：ide-si（Docker 开发容器，Ubuntu，原 si-11-ide）
# 平台配置在 ../_container_/（容器平台层，继承 _ubuntu_ 系统基础），Linux 系公共在 ../_linux_/，跨平台在 ../_common_/
# 多台 ide 部署时新增机器目录即可（flake 对不存在的机器目录自动跳过）

{ tools, ... }:
{
  imports = tools.scan ./.;
}
