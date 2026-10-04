# vscode（NixOS 真机）：包本体走 unstable 通道（nixpkgs 稳定版 vscode 版本旧），扩展/设置同 mac
# 封装见 modules/home/vscode.nix；扩展清单在 modules/home/vscode-extensions.nix（单一 manifest）
{ pkgs, ... }:
{
  vscode.enable = true;
  vscode.package = pkgs.repos.unstable.vscode;
  # nixos 平台差异设置（mac 无标题栏/菜单样式概念）
  vscode.settings = {
    "window.titleBarStyle" = "native";
    "window.menuStyle" = "custom";
  };
}
