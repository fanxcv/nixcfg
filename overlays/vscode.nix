# nix-vscode-extensions 补充市场注入（pkgs.repos.vscode）
# 主市场用 pkgs.repos.unstable.vscode-extensions（nixpkgs-unstable 内置，扩展版本较新，无 IFD）
# 仅 nixpkgs 缺失的扩展才引用本市场的 marketplace-release（如 bufbuild.vscode-buf，见 docs/tsln-vscode.yaml）
# 注意：本市场 eval 时需 IFD 拉取扩展清单（nix 2.18+ 默认允许），未引用的配置不触发
{ inputs, ... }: final: prev: {
  repos = (prev.repos or { }) // {
    vscode = inputs.vscode-extensions.overlays.default final prev;
  };
}
