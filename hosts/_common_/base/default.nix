# 跨平台系统公共模块（NixOS 与 nix-darwin 共用）
# 新增模块：新建 .nix 文件即生效（tools.scan）

{
  inputs,
  outputs,
  tools,
  ...
}:
{
  imports = tools.scan ./.;
}
