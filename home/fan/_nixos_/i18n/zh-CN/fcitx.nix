# fcitx5 中文输入法（tsln 完整版）：全拼默认 + 拼字/云拼音动画/标点策略；
# 皮肤：Material-Color（hosxy/Fcitx5-Material-Color）teal + 单行候选；Catppuccin 皮肤已关
# 主题只投放 XDG_DATA_HOME（fcitx5 恒查 ~/.local/share/fcitx5/themes），不走 addons 的
# XDG_DATA_DIRS——会话里 fcitx5 由系统 profile 的 wrapper 启动时也能看到
# 候选字号只能写在 classicui.conf 的 Font（fcitx5 5.1.x 已删除主题里的 [InputPanel] Font，
# 改主题的 theme.conf 是无效改动）
# 输入法前端：跟随 tsln 用 Wayland 前端（waylandFrontend = true）——GTK/Qt 的 IM 环境变量
#   改由 gtk{2,3,4} 的 gtk-im-module 提供；切 X11 会话（plasmax11）时
#   非 GTK 的 Qt/X11 应用若不走 IM module，需回退此开关为 false
# HM 设 GTK_IM_MODULE/QT_IM_MODULE/XMODIFIERS（登录 shell）；图形会话由系统层
# i18n.inputMethod 补（见 hosts/<机>/default.nix）
{
  lib,
  pkgs,
  isContainer ? false,
  ...
}:
{
  xdg.dataFile."fcitx5/themes/Material-Color-teal".source =
    "${pkgs.fcitx5-material-color}/share/fcitx5/themes/Material-Color-teal";

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
          classicui.globalSection = {
            # 候选字号 14pt（catppuccin 主题时代 13 → 曾放大到 16，视觉偏大回调一档）
            Font = "Noto Sans CJK SC 14";
            Theme = "Material-Color-teal";
            "Vertical Candidate List" = "False"; # 单行候选（主题 README 推荐配置）
            PerScreenDPI = "True";
          };
          pinyin.globalSection = {
            "FirstRun" = "False";
            "PageSize" = 7; # 单行候选 9 → 7，免面板过宽
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
