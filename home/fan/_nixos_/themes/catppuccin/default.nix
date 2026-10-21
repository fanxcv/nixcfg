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

    # CLI 工具（tsln 原版逐项显式开；autoEnable 关时必须逐项声明，flavor 覆全局 latte）
    # 生效前提：eza/atuin/btop/delta/helix/obsidian 的 target 需 programs.<x>.enable 才落配置。
    #   本仓库这些工具多数只装包不启用 HM 程序模块 → 那些 enable 当前是空转；
    #   已装且安全的两个（bat/eza）在下面 files 单独开程序模块，其余等要用时再开：
    #   btop/starship/atuin/helix/zellij/delta/obsidian 均未安装，开了会连带装包/改提示符
    obsidian.enable = lib.mkDefault true;
    bat.enable = lib.mkDefault true;
    bat.flavor = lib.mkDefault "mocha";
    eza.enable = lib.mkDefault true;
    eza.flavor = lib.mkDefault "mocha";
    k9s.flavor = lib.mkDefault "mocha";
    tmux.enable = lib.mkDefault true;
    tmux.flavor = lib.mkDefault "mocha";
    zellij.enable = lib.mkDefault true;
    zellij.flavor = lib.mkDefault "mocha";
    lazygit.flavor = lib.mkDefault "mocha";
    starship.enable = lib.mkDefault true;
    starship.flavor = lib.mkDefault "mocha";
    atuin.enable = lib.mkDefault true;
    atuin.flavor = lib.mkDefault "mocha";
    btop.enable = lib.mkDefault true;
    btop.flavor = lib.mkDefault "mocha";
    delta.enable = lib.mkDefault true;
    delta.flavor = lib.mkDefault "mocha";
    fzf.flavor = lib.mkDefault "mocha";
    helix.enable = lib.mkDefault true;
    helix.flavor = lib.mkDefault "mocha";
    yazi.flavor = lib.mkDefault "mocha";
    alacritty.flavor = lib.mkDefault "mocha";
    zsh-syntax-highlighting.enable = lib.mkDefault true;
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
  # 端口源（catppuccin/<port> 的 GitHub tarball）改走 githubProxy 前缀：这些 FOD 不在
  #   cache.nixos.org（实测 nix-lenovo 闭包 13 个 catppuccin FOD 里 7 个缺，且
  #   catppuccin.cachix.org 同样缺），否则每台机器首次构建直连 github.com 下载。
  #   hash 固定 → 输出路径不变，命中缓存者（kde/plymouth/whiskers/壁纸）不受影响。
  #   fetchSubmodules 的端口走 fetchgit，禁用前缀（ghfast 不代理 git 协议）。
  catppuccin.sources = inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.overrideScope (
    final: prev: {
      whiskers = pkgs.catppuccin-whiskers;

      fetchCatppuccinPort =
        args:
        prev.fetchCatppuccinPort (
          args
          // lib.optionalAttrs (!(args.fetchSubmodules or false)) {
            githubBase = tools.githubFetchBase;
          }
        );
    }
  );

  # catppuccin.bat / catppuccin.eza 的 enable 只是开关，真正落配置需 programs.<x>.enable：
  #   本仓库 bat/eza 在 _common_/base.nix 只装包；不启程序模块的话主题永远不生效。
  #   eza 关 zsh integration：HM 会写 ls/ll/la 等 alias，与 shells.nix 自定义 alias 重叠。
  programs.bat.enable = lib.mkDefault true;
  programs.eza = {
    enable = lib.mkDefault true;
    enableZshIntegration = lib.mkDefault false;
  };
}
