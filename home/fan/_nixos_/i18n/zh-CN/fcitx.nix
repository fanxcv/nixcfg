# fcitx5 中文输入法（tsln 完整版）：全拼默认 + 拼字/云拼音动画/标点策略；
# 皮肤：Catppuccin 已随主题切换禁用（见 ../../themes/catppuccin.nix），用默认皮肤
# nix-pve 会话为 X11（plasmax11，RustDesk 捕获需要）→ waylandFrontend = false，
# HM 设 GTK_IM_MODULE/QT_IM_MODULE/XMODIFIERS（登录 shell）；图形会话由系统层
# i18n.inputMethod 补（见 hosts/nix-pve/default.nix）
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
            "DefaultIM" = "pinyin";
          };
          "Groups/0/Items/0"."Name" = "keyboard-us";
          "Groups/0/Items/1"."Name" = "pinyin";
        };
        addons = {
          pinyin.globalSection = {
            "FirstRun" = "False";
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
      waylandFrontend = false;
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
