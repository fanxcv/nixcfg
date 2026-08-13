# GUI 桌面应用（ide 容器是无头开发环境，跳过桌面应用/Plasma；真机如 nix-pve 保留）
{ tools, lib, isContainer ? false, ... }:
{
  imports = lib.optionals (!isContainer) (tools.scan ./.);
}
