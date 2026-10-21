# Catppuccin（仅 NixOS）：上游 catppuccin/nix home target 封装 + 全局开关
# 上游模块的 import 在 ../default.nix（_nixos_ 层），故非 NixOS 平台不持有 catppuccin.* 选项
# 自封装 target 在本目录（plasma/konsole/wallpaper），由 tools.scan 自动导入
{
  lib,
  tools,
  pkgs,
  inputs,
  ...
}:
{
  imports = tools.scan ./.;

  catppuccin = {
    # 全局默认（tsln 同款策略）：enable 总开关 + autoEnable 关（target 手动开）
    # flavor latte 亮色 + blue 强调；CLI 工具类预设 mocha 深色（target enable 未开不生效）
    enable = true;
    autoEnable = false;

    flavor = lib.mkDefault "latte";
    accent = lib.mkDefault "blue";

    # CLI 工具预设（flavor 覆盖全局 latte；enable 未开不生效，仅预设）
    bat.flavor = lib.mkDefault "mocha";
    eza.flavor = lib.mkDefault "mocha";
    k9s.flavor = lib.mkDefault "mocha";
    tmux.flavor = lib.mkDefault "mocha";
    zellij.flavor = lib.mkDefault "mocha";
    lazygit.flavor = lib.mkDefault "mocha";
    starship.flavor = lib.mkDefault "mocha";
    atuin.flavor = lib.mkDefault "mocha";
    btop.flavor = lib.mkDefault "mocha";
    delta.flavor = lib.mkDefault "mocha";
    fzf.flavor = lib.mkDefault "mocha";
    helix.flavor = lib.mkDefault "mocha";
    yazi.flavor = lib.mkDefault "mocha";
    alacritty.flavor = lib.mkDefault "mocha";
    zsh-syntax-highlighting.flavor = lib.mkDefault "mocha";

    # KDE 主题切换（tsln 原版）：Plasma 配色/开机画面/光标（plasma.nix）、
    # 壁纸（桌面+锁屏，wallpaper.nix）、Konsole 配色（konsole.nix，mocha）
    # fcitx5 皮肤不用 Catppuccin：改用 Material-Color teal 单行（_nixos_/i18n/zh-CN/fcitx.nix）
    plasma.enable = lib.mkDefault true;
    wallpaper.enable = lib.mkDefault true;
    fcitx5.enable = lib.mkDefault false;
    konsole.enable = lib.mkDefault true;
    konsole.flavor = lib.mkDefault "mocha";
  };

  # 上游主题源替换（whiskers 模板工具换 nixpkgs 版，避免上游自带旧版）
  catppuccin.sources = inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.overrideScope (
    final: prev: {
      whiskers = pkgs.catppuccin-whiskers;
    }
  );
}
