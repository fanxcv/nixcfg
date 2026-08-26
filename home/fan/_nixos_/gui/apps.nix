# GUI 应用（对齐 mac 常用：Edge 浏览器 / Bitwarden 密码）
# 不做声明式扩展安装（mac 的 External Extensions 机制 Linux 不通用，扩展在应用内装）
# 注：rustdesk / clash-verge-rev 曾在此但已移除——nixpkgs 最新版无二进制缓存，
#   安装时需源码编译（rustdesk）/ GitHub 下载（clash 的 libsciter），拖慢整机部署；
#   需要时在真机上单独 nix profile install 即可
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    microsoft-edge # 浏览器（mac 同款；nixpkgs 标记 unfree，flake 已放行）
    bitwarden-desktop # 密码管理（mac 同款）
  ];
}
