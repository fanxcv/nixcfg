# mba-m5 用户配置（home-manager，内嵌于 nix-darwin）
# 组装：_common_（跨平台共享，darwin 兼容项全部可用）+ _darwin_（平台层）+ 本机微调
# 注意：home-manager 内嵌模式下本文件是唯一入口（不再走 flake 的 mkHomeConfig 注入）
{ tools, ... }:
{
  imports = [
    ../_common_
    ../_darwin_
  ] ++ (tools.scan ./.);
}
