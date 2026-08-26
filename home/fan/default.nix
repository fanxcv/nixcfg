# home-manager 入口（所有机器共用）
# home/fan/module-list.nix 统一注入 _common_、平台层和机器层；此入口仅保留 Home Manager 自身配置。

_: {
  # 让 home-manager 命令本身可用（以后可以直接 home-manager switch）
  programs.home-manager.enable = true;
}
