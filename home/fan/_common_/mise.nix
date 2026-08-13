# mise：多语言运行时管理（对应 alpine-init.sh 的 install_mise()）
# 组件清单按机器声明：机器写了 ~/.config/mise/config.toml（mini-m4 / ide 容器）即整体接管，
# 机器没指定时走全局默认（下方 mkDefault）——只声明 node@lts（pi 的 runtime 依赖，见 pi.nix）
# 全部配置变更都维持在 config.toml 这一个文件里：mkDefault 让机器级普通赋值直接覆盖，
# 不引入 config.local.toml 或其他文件叠加
# shims 进 PATH 用 home.sessionPath（与 ~/.local/bin 同一机制，注入 HM 管理的所有 shell）
# darwin 也装包：mini-m4 的组件由 nix 声明（config.toml 见 home/fan/mini-m4/mise.nix）

{ pkgs, lib, ... }:
{
  # usage 是 mise 的 shell 补全/激活辅助 CLI（mise 不自带），装 mise 必装 usage
  home.packages = [ pkgs.mise pkgs.usage ];

  home.sessionPath = [
    "$HOME/.local/share/mise/shims"
  ];

  # 全局默认组件：node@lts（mkDefault = 仅当机器没指定 config.toml 时生效；机器普通赋值即覆盖）
  home.file.".config/mise/config.toml" = lib.mkDefault {
    text = ''
      [tools]
      node = "lts"
    '';
  };
}
