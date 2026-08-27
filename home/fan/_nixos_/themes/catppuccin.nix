# Catppuccin NixOS 用户级主题开关（tsln 同款）：桌面 + 输入法皮肤 + 壁纸 + Konsole
{ lib, ... }:
{
  catppuccin = {
    plasma.enable = lib.mkDefault true;
    fcitx5.enable = lib.mkDefault true;
    wallpaper.enable = lib.mkDefault true;

    konsole.enable = lib.mkDefault true;
    konsole.flavor = lib.mkDefault "mocha";
  };
}
