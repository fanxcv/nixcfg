# Plasma 桌面定制（plasma-manager）：细节拆分见 plasma.*.nix（tsln 同款结构）
# 模块本体挂 home/fan/_common_/default.nix（全平台）；主题开关在 ../../themes/catppuccin.nix
{ tools, ... }:
{
  imports = tools.scan ./.;

  programs.plasma.enable = true;
}
