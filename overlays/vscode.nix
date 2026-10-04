# nix-vscode-extensions 市场注入（pkgs.repos.vscode）
# 扩展来源两路（清单见 modules/home/vscode-extensions.nix）：
#   1) pkgs.vscode-extensions —— nixpkgs 内置，主市场，无 IFD
#   2) pkgs.repos.vscode.vscode-marketplace-release —— 本 flake 的 release 通道，补 nixpkgs 缺失/滞后项
#      （autopep8 / vscode-buf / csv-grid-editor / pencildev）；禁本地自打包扩展
# 注意：本市场 eval 时需 IFD 拉取扩展清单（nix 2.18+ 默认允许），未引用的配置不触发
{ inputs, ... }: final: prev: {
  repos = (prev.repos or { }) // {
    vscode = inputs.vscode-extensions.overlays.default final prev;
  };
}
