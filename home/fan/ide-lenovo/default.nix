# 机器专属：ide-lenovo（Docker 开发容器，Ubuntu，原 lenovo-ide）
# 平台配置在 ../_container_/（容器平台层，继承 _ubuntu_ 系统基础），Linux 系公共在 ../_linux_/，跨平台在 ../_common_/
# 本机差异：mise 组件（java oracle-17 + pipx，见 ../_container_/mise.nix 的 hostName 分支）；国内直连，无 sysenv 代理/hosts 配置

{ tools, ... }:
{
  imports = tools.scan ./.;
}
