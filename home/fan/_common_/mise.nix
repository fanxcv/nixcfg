# mise：多语言运行时管理（对应 alpine-init.sh 的 install_mise()）
# 组件清单已全部清空：装哪些工具/运行时晚点分机器逐一确定（mise use -g 后落到 config.toml，
#   或在此文件按机器声明；暂不写死任何组件）
# shims 进 PATH 用 home.sessionPath（与 ~/.local/bin 同一机制，注入 HM 管理的所有 shell，
#   而非只在 zsh initExtra 里 export）
# darwin 跳过：Mac 上 mise 已自管（~/.config/mise/config.toml 手配），不装包不写配置

{ pkgs, lib, ... }:
{
  home.packages = lib.mkIf (!pkgs.stdenv.isDarwin) [ pkgs.mise ];

  # 与 _common_/base.nix 的 ~/.local/bin 同机制，两个条目自动合并进 PATH
  home.sessionPath = lib.mkIf (!pkgs.stdenv.isDarwin) [
    "$HOME/.local/share/mise/shims"
  ];
}
