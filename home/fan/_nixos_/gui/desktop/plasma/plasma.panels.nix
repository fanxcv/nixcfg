# 面板布局重排（tsln→帖子方案）：上：启动器/窗口列表/全局菜单/间隙/数字时钟/间隙/托盘；下：图标任务栏 Dock
# Panel-colorizer 挂件给面板做透明/配色（nixpkgs plasma-panel-colorizer，插件 ID org.github.luisbocanegra.plasma.panelcolorizer）
# 上面板 ChromeOS 预设 + 禁 Color；下面板 Translucent 预设（帖子配置，见 blog.sotkg.com/2025/08/kde-customization）
{
  programs.plasma.panels = [
    # ── 上面板 ──
    {
      alignment = "center";
      floating = false;
      height = 30;
      hiding = "none";
      lengthMode = "fill";
      location = "top";
      offset = 0;
      opacity = "adaptive";
      widgets = [
        {
          name = "org.kde.plasma.kickoff";
          config = {
            popupHeight = 650;
            popupWidth = 750;
            General = {
              alphaSort = true;
              favoritesPortedToKAstats = true;
              icon = "distributor-logo-nixos";
              showRecentApps = false;
              showRecentDocs = false;
              systemFavorites = "suspend\\,hibernate\\,reboot\\,shutdown";
            };
          };
        }
        {
          name = "org.kde.plasma.windowlist";
          config = {
            General = {
              openOnHover = true;
              showText = false;
              showOnlyCurrentActivity = false;
              showOnlyCurrentDesktop = false;
              showOnlyCurrentScreen = false;
              showOnlyMinimized = false;
            };
          };
        }
        {
          name = "org.kde.plasma.globalmenu";
          config = {
            General = {
              showText = false;
            };
          };
        }
        {
          name = "org.kde.plasma.panelspacer";
        }
        {
          name = "org.kde.plasma.digitalclock";
          config = {
            popupHeight = 450;
            popupWidth = 450;
          };
        }
        {
          name = "org.kde.plasma.panelspacer";
        }
        {
          name = "org.kde.plasma.systemtray";
          config = {
            popupHeight = 450;
            popupWidth = 430;
            General = {
              iconSpacing = 1;
            };
          };
        }
        {
          name = "luisbocanegra.panel.colorizer";
          config = {
            General = {
              preset = "chromeos";
            };
            outline = {
              disableColor = true;
            };
          };
        }
      ];
    }
    # ── 下面板：图标任务管理器 Dock ──
    {
      alignment = "center";
      floating = true;
      height = 48;
      hiding = "none";
      lengthMode = "fit";
      location = "bottom";
      offset = 0;
      opacity = "adaptive";
      widgets = [
        {
          name = "org.kde.plasma.icontasks";
          config = {
            General = {
              launchers = [
                "applications:microsoft-edge.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:org.kde.konsole.desktop"
                "applications:org.kde.spectacle.desktop"
                "applications:code.desktop"
                "applications:bitwarden.desktop"
              ];
              showOnlyCurrentActivity = false;
              showOnlyCurrentDesktop = false;
              showOnlyCurrentScreen = false;
              showOnlyMinimized = false;
            };
          };
        }
        {
          name = "luisbocanegra.panel.colorizer";
          config = {
            General = {
              preset = "translucent";
            };
          };
        }
      ];
    }
  ];
}
