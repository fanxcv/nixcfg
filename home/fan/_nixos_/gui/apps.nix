# GUI 应用（对齐 mac 常用：Edge 浏览器 / Bitwarden 密码 / RustDesk 远程 / Clash 代理）
# 不做声明式扩展安装（mac 的 External Extensions 机制 Linux 不通用，扩展在应用内装）
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    microsoft-edge          # 浏览器（mac 同款；nixpkgs 标记 unfree，flake 已放行）
    bitwarden-desktop       # 密码管理（mac 同款）
    rustdesk                # 远程控制（mac 同款，走 tailnet）
    clash-verge-rev         # 代理客户端（mac 同款）
  ];
}
