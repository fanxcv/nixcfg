# Catppuccin home 层模块封装（tsln 思路）：引入上游 catppuccin/nix home target 源
# 仅设默认值（enable/autoEnable 默认关），实际开关在平台层 themes/catppuccin.nix
{
  lib,
  tools,
  pkgs,
  inputs,
  ...
}:
{
  imports = tools.scan ./.;

  catppuccin.enable = lib.mkOptionDefault false;
  catppuccin.autoEnable = lib.mkOptionDefault false;
  # 上游主题源替换（whiskers 模板工具换 nixpkgs 版，避免上游自带旧版）
  catppuccin.sources = inputs.catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.overrideScope (
    final: prev: {
      whiskers = pkgs.catppuccin-whiskers;
    }
  );
}
