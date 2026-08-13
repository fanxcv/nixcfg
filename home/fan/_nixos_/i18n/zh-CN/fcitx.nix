# fcitx5 中文输入法（拼音默认；双拼：DefaultIM 改 "shuangpin" + ShuangpinProfile 如 "MS"）
# Wayland 前端 + Plasma 虚拟键盘联动
{ lib, pkgs, isContainer ? false, ... }:
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
          "GroupOrder"."0" = "Default";
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
            "CloudPinyinEnabled" = "True";
            "CloudPinyinIndex" = 2;
          };
          cloudpinyin.globalSection = {
            "MinimumPinyinLength" = 4;
            "Backend" = "Baidu";
          };
        };
      };
      waylandFrontend = true;
    };
  };

  # Plasma 虚拟键盘联动（fcitx5-wayland-launcher；容器无桌面不加载此模块定义）
} // lib.optionalAttrs (!isContainer) {
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
