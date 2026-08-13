# Plasma 桌面定制（plasma-manager，参考 tsln minipc）：
# 底部浮动面板 + 4 虚拟桌面 + Noto CJK 字体 + KWin 贴边
{ inputs, lib, config, ... }:
let
  inherit (config.fonts.fontconfig) defaultFonts;
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

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
  };
}
