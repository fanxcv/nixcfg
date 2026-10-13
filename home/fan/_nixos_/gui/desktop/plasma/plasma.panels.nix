# 面板布局（tsln 原版）：单条底部 Dock——启动器/分页器/图标任务/间隙/窗口列表/
# 内存监控/CPU 监控/间隙/系统托盘/数字时钟/显示桌面
# 固定图标（icontasks launchers）换为本机已装应用（上游为 chromium/beekeeper-studio/gitcomet）
{
  programs.plasma.panels = [
    {
      alignment = "center";
      floating = true;
      height = 36;
      hiding = "none";
      lengthMode = "fill";
      location = "bottom";
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
          name = "org.kde.plasma.pager";
        }
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
              ];

              showOnlyCurrentActivity = false;
              showOnlyCurrentDesktop = false;
              showOnlyCurrentScreen = false;
              showOnlyMinimized = false;
            };
          };
        }
        {
          name = "org.kde.plasma.marginsseparator";
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
          name = "org.kde.plasma.systemmonitor";
          config = {
            CurrentPreset = "org.kde.plasma.systemmonitor";
            popupHeight = 400;
            popupWidth = 400;
            Appearance = {
              chartFace = "org.kde.ksysguard.linechart";
              title = "RAM";
              updateRateLimit = 0;
            };
            Sensors = {
              highPrioritySensorIds = ''["memory/physical/used"]'';
              lowPrioritySensorIds = ''["memory/physical/total"]'';
              totalSensors = ''["memory/physical/usedPercent"]'';
            };
          };
        }
        {
          name = "org.kde.plasma.systemmonitor";
          config = {
            CurrentPreset = "org.kde.plasma.systemmonitor";
            popupHeight = 400;
            popupWidth = 400;
            Appearance = {
              chartFace = "org.kde.ksysguard.linechart";
              title = "CPU";
              updateRateLimit = 1000;
            };
            Sensors = {
              highPrioritySensorIds = ''["cpu/all/usage"]'';
              lowPrioritySensorIds = ''["cpu/all/cpuCount","cpu/all/coreCount"]'';
              totalSensors = ''["cpu/all/usage"]'';
            };
          };
        }
        {
          name = "org.kde.plasma.marginsseparator";
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
          name = "org.kde.plasma.digitalclock";
          config = {
            popupHeight = 450;
            popupWidth = 450;
          };
        }
        {
          name = "org.kde.plasma.showdesktop";
        }
      ];
    }
  ];
}
