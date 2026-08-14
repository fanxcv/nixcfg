# Plasma 桌面定制（plasma-manager，参考 tsln minipc）：
# 底部浮动面板 + 4 虚拟桌面 + Noto CJK 字体 + KWin 贴边
# Catppuccin 主题（latte 亮色）+ Papirus 图标 + Konsole（mocha 配色）+ 界面中文
{ inputs, lib, config, pkgs, ... }:
let
  inherit (config.fonts.fontconfig) defaultFonts;
  # Catppuccin latte 壁纸（nixpkgs 的 nixos-artwork 自带，路径同 tsln）
  wallpaper = "${pkgs.nixos-artwork.wallpapers."catppuccin-latte"}/share/backgrounds/nixos/nixos-wallpaper-catppuccin-latte.png";
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  # Catppuccin 桌面主题（latte 亮色 + blue 强调，nixpkgs 自带包）+ Papirus 图标（亮色版；
  # tsln 原配置两分支都写 Papirus-Dark 是笔误，latte 应配亮色 Papirus）+ Konsole 终端（mocha 配色见下）
  home.packages = [
    (pkgs.catppuccin-kde.override {
      flavour = [ "latte" ];
      accents = [ "blue" ];
    })
    pkgs.papirus-icon-theme
    pkgs.kdePackages.konsole
  ];

  programs.plasma = {
    enable = true;

    # 主题：Catppuccin Latte 配色/开机画面 + Papirus 亮色图标 + 桌面壁纸
    workspace = {
      colorScheme = "CatppuccinLatteBlue";
      splashScreen.theme = "Catppuccin-Latte-Blue";
      cursor.theme = "Breeze_Light";
      iconTheme = "Papirus";
      inherit wallpaper;
    };

    # 锁屏壁纸（与桌面同款）
    kscreenlocker.appearance = { inherit wallpaper; };

    # 字体：跟随 fontconfig 默认（Noto CJK），统一 10pt
    fonts = {
      general = {
        family = lib.head defaultFonts.sansSerif;
        pointSize = 10;
      };
      fixedWidth = {
        family = lib.head defaultFonts.monospace;
        pointSize = 10;
      };
      menu = {
        family = lib.head defaultFonts.sansSerif;
        pointSize = 10;
      };
      small = {
        family = lib.head defaultFonts.sansSerif;
        pointSize = 8;
      };
      windowTitle = {
        family = lib.head defaultFonts.sansSerif;
        pointSize = 10;
      };
      toolbar = {
        family = lib.head defaultFonts.sansSerif;
        pointSize = 10;
      };
    };

    # 底部浮动面板：启动器 + 任务栏 + 托盘 + 时钟
    panels = [
      {
        alignment = "center";
        floating = true;
        height = 36;
        hiding = "none";
        lengthMode = "fill";
        location = "bottom";
        opacity = "adaptive";
        widgets = [
          {
            name = "org.kde.plasma.kickoff";
            config = {
              popupHeight = 650;
              popupWidth = 750;
              General = {
                alphaSort = true;
                icon = "distributor-logo-nixos";
                showRecentApps = false;
                showRecentDocs = false;
                systemFavorites = "suspend\\,reboot\\,shutdown";
              };
            };
          }
          {
            name = "org.kde.plasma.pager";
          }
          {
            name = "org.kde.plasma.icontasks";
          }
          {
            name = "org.kde.plasma.systemtray";
          }
          {
            name = "org.kde.plasma.digitalclock";
          }
        ];
      }
    ];

    # KWin：4 虚拟桌面（2x2）+ 窗口贴边吸附
    configFile.kwinrc = {
      Desktops = {
        Number = 4;
        Rows = 2;
      };
      Windows = {
        RollOverDesktops = true;
        BorderSnapZone = 10;
        WindowSnapZone = 10;
      };
    };

    # 会话：空会话启动（不恢复上次桌面）
    configFile.ksmserverrc.General = {
      loginMode = "emptySession";
    };

    # 界面中文：写 ~/.config/plasma-localerc，只影响 KDE 界面；终端/SSH 环境保持 en_US
    # （与 mac 的 AppleLanguages 策略一致：界面中文、环境英文，见 hosts/_darwin_/i18n/locale.nix）
    configFile."plasma-localerc" = {
      Translations = { Language = "zh_CN"; };
    };
  };

  # Konsole 终端：catppuccin mocha 配色（配色文件自打包，软链到 ~/.local/share/konsole/）
  home.file.".local/share/konsole/catppuccin-mocha.colorscheme".source =
    "${pkgs.catppuccin-konsole}/catppuccin-mocha.colorscheme";

  programs.konsole = {
    enable = true;
    ui.colorScheme = "BreezeDark";
    profiles.Default = {
      colorScheme = "catppuccin-mocha";
      font = {
        name = lib.head defaultFonts.monospace;
        size = 11;
      };
    };
  };
}
