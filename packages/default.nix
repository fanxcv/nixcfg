# 本地包集合（tsln 的 packages 思路）：nixpkgs 缺失的自打包
# 经 flake.nix 的 packages output 合并导出（nix build .#<包名>）
# home 配置里引用：import 本文件传 pkgs（见 home/fan/nix-pve/rustdesk.nix）
pkgs: {
  # 官方 GitHub Release 二进制（deb 解包），免 rustdesk 源码编译（无缓存，编译 ~1h）
  rustdesk-bin = pkgs.callPackage ./rustdesk-bin.nix { };

  # Catppuccin Konsole 配色（nixpkgs 26.05 无此包，固定 rev 自打包；→ home/fan/_nixos_/gui/plasma.nix）
  catppuccin-konsole = pkgs.callPackage ./catppuccin/konsole.nix { };
}
