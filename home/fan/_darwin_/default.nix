# macOS 用户层配置（home-manager，内嵌于 nix-darwin）
# 自动扫描导入：新增 .nix 文件即生效

# 身份与 stateVersion 由 ../_common_/identity.nix 统一声明。

{ tools, ... }:
{
  imports = tools.scan ./.;
}
