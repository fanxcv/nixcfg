# 底部浮动面板（tsln 完整版）：启动器 + 分页器 + 图标任务栏 + 窗口列表 + RAM/CPU 监视器 +
# 托盘 + 时钟 + 显示桌面；launchers 对齐当前仓应用集（apps.nix：Edge/Bitwarden + vscode）
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
              # 固定启动器：与已装应用对齐（Edge/Bitwarden 见 gui/apps.nix，vscode 见 gui/apps/vscode.nix）
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
