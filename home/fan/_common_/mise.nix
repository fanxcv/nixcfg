# mise：多语言运行时管理（对应 alpine-init.sh 的 install_mise()）
# 组件清单按机器声明（mise use -g 后落到 config.toml，或直接改 wanted.yaml 的
# mini_m4.mise 段 → home/fan/mini-m4/mise.nix；其他机器暂不声明组件）
# shims 进 PATH 用 home.sessionPath（与 ~/.local/bin 同一机制，注入 HM 管理的所有 shell）
# darwin 也装包：mini-m4 的组件由 nix 声明（config.toml 见 home/fan/mini-m4/mise.nix）

{ pkgs, ... }:
{
  # usage 是 mise 的 shell 补全/激活辅助 CLI（mise 不自带），装 mise 必装 usage
  home.packages = [ pkgs.mise pkgs.usage ];

  home.sessionPath = [
    "$HOME/.local/share/mise/shims"
  ];
}
