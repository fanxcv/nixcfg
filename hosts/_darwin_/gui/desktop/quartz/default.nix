# Quartz 桌面设置模块集合（tools.scan 需要子目录含 default.nix 才会导入）
{ tools, ... }:
{
  imports = tools.scan ./.;
}
