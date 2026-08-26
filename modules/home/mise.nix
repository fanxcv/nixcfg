# mise 运行时模块（从 _common_/mise.nix 迁入，加 softwares.mise.enable 门控）
# 组件清单按机器声明：机器写了 ~/.config/mise/config.toml（mini-m4 / ide 容器）即整体接管，
# 机器没指定时不再装任何默认组件——node@lts 已改由 nix 包管理（见 base.nix 的 nodejs）。
# 机器级 mise node 仍覆盖全局 nix node：shims 经 home.sessionPath prepend 到 PATH，
# 优先于 nix profile 的 bin（mini-m4@24 / ide 容器@22 生效）
# 全部配置变更都维持在 config.toml 这一个文件里：机器级普通赋值即覆盖，不引入 config.local.toml
# shims 进 PATH 用 home.sessionPath（与 ~/.local/bin 同一机制，注入 HM 管理的所有 shell）
# darwin 也装包：mini-m4 的组件由 nix 声明（config.toml 见 home/fan/mini-m4/mise.nix）
# 启用：common 默认 enable=true；某台不装 → 机器层 softwares.mise.enable = lib.mkForce false

{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.softwares.mise.enable = lib.mkEnableOption "mise 运行时管理器（包 + shims PATH）";

  config = lib.mkIf config.softwares.mise.enable {
    # usage 是 mise 的 shell 补全/激活辅助 CLI（mise 不自带），装 mise 必装 usage
    home.packages = [
      pkgs.mise
      pkgs.usage
    ];

    home.sessionPath = [
      "$HOME/.local/share/mise/shims"
    ];
  };
}
