# 本地包集合（tsln 的 packages 思路）：nixpkgs 缺失的自打包
# 经 flake.nix 的 packages output 合并导出（nix build .#<包名>）
# home 配置里引用：import 本文件传 pkgs（见 home/fan/nix-pve/rustdesk.nix）
# githubFetchBase：GitHub 加速 base（来自 tools/config.nix 集中配置），包构建期编 GitHub 时用
{
  pkgs,
  githubFetchBase ? "github.com",
}:
let
  # 官方 GitHub Release 二进制（deb 解包），免 rustdesk 源码编译（无缓存，编译 ~1h）
  # 仅 x86_64-linux（nix-pve 用）；darwin 走 brew + 注入脚本（见 hosts/_darwin_/base/rustdesk.nix）
  rustdesk = pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    rustdesk-bin = pkgs.callPackage ./rustdesk-bin.nix { };
  };
in
rustdesk
// {

  # VSCode 扩展：CSV Grid Editor（补市场缓存滞后 → 官方 vsix 直链 1.18.4）
  csv-grid-editor = pkgs.callPackage ./csv-grid-editor.nix { };

  # KasmVNC：浏览器远程桌面（nixpkgs 无此包；→ home/fan/ide-lenovo/kasmvnc.nix）
  kasmvnc = pkgs.callPackage ./kasmvnc.nix { };

  # Catppuccin Konsole 配色（nixpkgs 26.05 无此包，固定 rev 自打包；→ home/fan/_nixos_/gui/plasma.nix）
  # 网络：fetchFromGitHub 默认直连 github.com（国内不稳），githubBase 换加速前缀（代理不改内容，hash 不重算）
  catppuccin-konsole = pkgs.callPackage ./catppuccin/konsole.nix { githubBase = githubFetchBase; };

  # --- KDE 帖子美化主题（blog.sotkg.com/2025/08/kde-customization，仅 nix-pve/nix-book 用）---
  # Moe 全套（颜色/Plasma 样式/look-and-feel，GitLab fetchgit）
  moe-kde = pkgs.callPackage ./moe-kde.nix { };
  # Fedora 全局主题（koji rpm fetchurl + rpm2cpio）
  fedora-look-and-feel = pkgs.callPackage ./fedora-look-and-feel.nix { };
  # Redmi Clock plasmoid / Hoshino 光标（vendor 到 assets/kde-sources/，本地文件）
  redmi-clock = pkgs.callPackage ./redmi-clock.nix { };
  hoshino-cursor = pkgs.callPackage ./hoshino-cursor.nix { };
  # McMojave 图标/KDE 主题（macOS 风格，GitHub tarball fetchzip）
  mcmojave-circle = pkgs.callPackage ./mcmojave-circle.nix { };
  mcmojave-kde = pkgs.callPackage ./mcmojave-kde.nix { };
  # MacTahoe KDE/GTK 主题 + Catppuccin KDE（vendor 到 assets/kde-sources/，本地文件）
  mactahoe-kde = pkgs.callPackage ./mactahoe-kde.nix { };
  mactahoe-gtk = pkgs.callPackage ./mactahoe-gtk.nix { };
  catppuccin-kde = pkgs.callPackage ./catppuccin-kde.nix { };
}
