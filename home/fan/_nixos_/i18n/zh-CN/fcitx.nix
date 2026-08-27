# fcitx5 中文输入法（tsln 完整版）：双拼 MS 默认 + 拼字/云拼音动画/标点策略；
# 皮肤走 Catppuccin（catppuccin.fcitx5.enable，见 ../../themes/catppuccin.nix）
# Wayland 前端 + Plasma 虚拟键盘联动
{
  lib,
  pkgs,
  isContainer ? false,
  ...
}:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [
        pkgs.kdePackages.fcitx5-chinese-addons
      ];
      settings = {
        inputMethod = {
          "GroupOrder" = {
            "0" = "Default";
          };
          "Groups/0" = {
            "Name" = "Default";
            "Default Layout" = "us";
            "DefaultIM" = "shuangpin";
          };
          "Groups/0/Items/0"."Name" = "keyboard-us";
          "Groups/0/Items/1"."Name" = "shuangpin";
        };
        addons = {
          pinyin.globalSection = {
            "FirstRun" = "False";
            "ShuangpinProfile" = "MS";
            "PageSize" = 9;
            "SpellEnabled" = "True";
            "SymbolsEnabled" = "True";
            "ChaiziEnabled" = "True";
            "CloudPinyinEnabled" = "True";
            "CloudPinyinIndex" = 2;
            "CloudPinyinAnimation" = "True";
          };
          cloudpinyin.globalSection = {
            "MinimumPinyinLength" = 4;
            "Backend" = "Baidu";
            "Toggle Key" = "";
          };
          punctuation.globalSection = {
            "Enabled" = "True";
            "HalfWidthPuncAfterLetterOrNumber" = "True";
            "TypePairedPunctuationsTogether" = "False";
          };
        };
      };
      waylandFrontend = true;
    };
  };
}
// lib.optionalAttrs (!isContainer) {
  # Plasma 虚拟键盘联动（fcitx5-wayland-launcher；容器无桌面不加载此模块定义）
  programs.plasma.configFile.kwinrc = {
    Wayland = {
      VirtualKeyboardEnabled = {
        value = true;
      };
      InputMethod = {
        shellExpand = true;
        value = "$HOME/.nix-profile/share/applications/fcitx5-wayland-launcher.desktop";
      };
    };
  };
}
