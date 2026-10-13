# fcitx5 中文输入法（tsln 完整版）：全拼默认 + 拼字/云拼音动画/标点策略；
# 皮肤：Catppuccin 已随主题切换禁用（见 ../../themes/catppuccin.nix），用默认皮肤
# nix-pve 会话为 X11（plasmax11，RustDesk 捕获需要）→ waylandFrontend = false，
# HM 设 GTK_IM_MODULE/QT_IM_MODULE/XMODIFIERS（登录 shell）；图形会话由系统层
# i18n.inputMethod 补（见 hosts/nix-pve/default.nix）
{
  lib,
  pkgs,
  config,
  isContainer ? false,
  ...
}:
let
  catFcitx5 = config.catppuccin.fcitx5;
  themeName = "catppuccin-${catFcitx5.flavor}-${catFcitx5.accent}";
  # catppuccin 主题自带 [InputPanel] Font=Sans 13，候选字偏小；
  # 用户目录同名主题覆盖（fcitx5 主题查找 XDG_DATA_HOME 优先于包内 XDG_DATA_DIRS）
  candidateFontSize = 16;
  largeFontTheme = pkgs.runCommand "fcitx5-${themeName}-font-${toString candidateFontSize}" { } ''
    cp -r ${pkgs.catppuccin-fcitx5}/share/fcitx5/themes/${themeName} $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i -E 's/^Font=Sans [0-9]+$/Font=Sans ${toString candidateFontSize}/' $out/theme.conf
    grep -q '^Font=Sans ${toString candidateFontSize}$' $out/theme.conf
  '';
in
{
  xdg.dataFile = lib.mkIf catFcitx5.enable {
    "fcitx5/themes/${themeName}".source = largeFontTheme;
  };

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
