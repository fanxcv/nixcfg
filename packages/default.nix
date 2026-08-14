# 本地包集合（tsln 的 packages 思路）：nixpkgs 缺失的自打包
# 经 flake.nix 的 packages output 合并导出（nix build .#<包名>）
# 当前无本地包；需要时参照 tsln 的 packages/catppuccin/konsole.nix 模式新增
pkgs: { }
