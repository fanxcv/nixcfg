# vscode（mac）：商店版 App + nix 声明扩展/设置（封装见 modules/home/vscode.nix）
# 扩展清单见 modules/home/vscode.nix：base 公共（含 remote-ssh）由 default/python/go 三 profile 共用
# 应用本体更新走商店，不受 nix 管
_: {
  vscode.enable = true;
  # package 默认 null = 不装 nix 包（商店版）；扩展/设置由 nix 锁定，编辑器内不可增删
}
