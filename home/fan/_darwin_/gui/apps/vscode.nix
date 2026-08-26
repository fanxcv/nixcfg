# vscode（mac）：商店版 App + nix 声明扩展/设置（封装见 modules/home/vscode.nix）
# 扩展清单见 docs/tsln-vscode.yaml：base 公共 18 个（含 remote-ssh，自 darwin_only 公共化）
# 应用本体更新走商店，不受 nix 管
_: {
  vscode.enable = true;
  # package 默认 null = 不装 nix 包（商店版）；扩展/设置由 nix 锁定，编辑器内不可增删
}
