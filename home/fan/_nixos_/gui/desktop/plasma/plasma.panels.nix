# 面板布局：上：启动器/窗口列表/间隙/数字时钟/间隙/托盘；下：图标任务栏 Dock（上下分栏为 nixcfg 保留项）
# 注：globalmenu 曾在此（org.kde.plasma.globalmenu 在目标机加载失败报“软件包不存在”，已移除；
#     需要 macOS 顶栏菜单效果时须先查该 applet 在对应 Plasma 版本是否随 plasma-workspace 提供）
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
            globalSettings = builtins.toJSON {
              stockPanelSettings.opacity = {
                enabled = true;
                value = "60";
              };
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
          name = "org.kde.plasma.showdesktop";
        }
      ];
    }
  ];
}
