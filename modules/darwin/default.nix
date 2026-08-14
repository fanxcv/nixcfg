# darwin 系统层模块库（tsln 的 modules/darwin 思路）：平台通用系统模块
# 被 hosts/_darwin_/base/default.nix 引用（outputs.darwinModules.default）；容器/linux 不经过，天然隔离
# 与 hosts/_darwin_/base/ 的分工：这里放可复用系统模块，base 放平台组装（homebrew/agenix/home-manager 挂载）
{ tools, ... }:
{
  imports = tools.scan ./.;
}
