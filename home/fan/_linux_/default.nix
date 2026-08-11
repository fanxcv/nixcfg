# Linux 系公共层（NixOS 真机 + Alpine 服务器 + Linux 容器共用）
# 从 _nixos_/_alpine_ 提取的公共部分；mac 系统自带对应工具，故不进 _common_
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效（当前：base.nix / docker.nix）

{ tools, ... }:
{
  imports = tools.scan ./.;
}
