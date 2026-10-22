# 本地包集合（tsln 的 packages 思路）：nixpkgs 缺失的自打包
# 经 flake.nix 的 packages output 合并导出（nix build .#<包名>）
# 引用：flake.nix 的 localPkgsOverlay（import 本文件传 pkgs）
# githubFetchBase：GitHub 加速 base（来自 tools/config.nix 集中配置），包构建期编 GitHub 时用
{
  pkgs,
  githubFetchBase ? "github.com",
}:
let
  lib = pkgs.lib;
  # 平铺包文件自动注册：新增 packages/<name>.nix 即生效，零注册改动
  # 平台条件/需额外参数的包在下方显式注册，其文件从自动扫描排除（免被无条件注册）
  explicitFiles = [
    "kasmvnc.nix"
    "rustdesk-bin.nix"
  ];
  autoPkgs =
    lib.mapAttrs'
      (
        name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (pkgs.callPackage (./. + "/${name}") { })
      )
      (
        lib.filterAttrs (
          name: type:
          type == "regular"
          && lib.hasSuffix ".nix" name
          && name != "default.nix"
          && !(builtins.elem name explicitFiles)
        ) (builtins.readDir ./.)
      );
in
autoPkgs
// lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  # 官方 GitHub Release 二进制（deb 解包），免 rustdesk 源码编译（无缓存，编译 ~1h）
  # 仅 x86_64-linux；darwin 走 brew + 注入脚本（见 hosts/_darwin_/base/rustdesk.nix）
  rustdesk-bin = pkgs.callPackage ./rustdesk-bin.nix { };
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  # KasmVNC：浏览器远程桌面（仅 linux：官方 deb 解包含 arm64/amd64 分支；nixpkgs 无此包）
  # → home/fan/_container_/kasmvnc.nix（ide 三容器共用）
  kasmvnc = pkgs.callPackage ./kasmvnc.nix { };
}
// {
  # Catppuccin Konsole 配色（nixpkgs 26.05 无此包，固定 rev 自打包；→ home/fan/_nixos_/themes/catppuccin/konsole.nix）
  # 网络：fetchFromGitHub 默认直连 github.com（国内不稳），githubBase 换加速前缀（代理不改内容，hash 不重算）
  catppuccin-konsole = pkgs.callPackage ./catppuccin/konsole.nix { githubBase = githubFetchBase; };
}
