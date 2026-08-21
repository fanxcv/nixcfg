# 本地包集合（tsln 的 packages 思路）：nixpkgs 缺失的自打包
# 经 flake.nix 的 packages output 合并导出（nix build .#<包名>）
# home 配置里引用：import 本文件传 pkgs（见 home/fan/nix-pve/rustdesk.nix）
# githubFetchBase：GitHub 加速 base（来自 tools/config.nix 集中配置），包构建期编 GitHub 时用
{ pkgs, githubFetchBase ? "github.com" }:
{
  # 官方 GitHub Release 二进制（deb 解包），免 rustdesk 源码编译（无缓存，编译 ~1h）
  rustdesk-bin = pkgs.callPackage ./rustdesk-bin.nix { };

  # VSCode 扩展：CSV Grid Editor（补市场缓存滞后 → 官方 vsix 直链 1.18.4）
  csv-grid-editor = pkgs.callPackage ./csv-grid-editor.nix { };

  # Catppuccin Konsole 配色（nixpkgs 26.05 无此包，固定 rev 自打包；→ home/fan/_nixos_/gui/plasma.nix）
  # 网络：fetchFromGitHub 默认直连 github.com（国内不稳），githubBase 换加速前缀（代理不改内容，hash 不重算）
  catppuccin-konsole = pkgs.callPackage ./catppuccin/konsole.nix { githubBase = githubFetchBase; };
}