# 菜单栏声明（system.defaults：时钟 + 控制中心）
{
  system.defaults = {
    NSGlobalDomain = {
      # 24 小时制
      AppleICUForce24HourTime = true;
    };

    menuExtraClock = {
      # 冒号常亮不闪烁
      FlashDateSeparators = false;
      # 数字时钟
      IsAnalog = false;
      # 24 小时显示
      Show24Hour = true;
      # 保留 AM/PM 标签（24 小时制下通常不显示）
      ShowAMPM = true;
      # 显示星期
      ShowDayOfWeek = true;
      # 日期"空间允许时显示"
      ShowDate = 0;
    };

    controlcenter = {
      # 电池图标显示百分比
      BatteryShowPercentage = true;
    };

    CustomUserPreferences = {
      NSGlobalDomain = {
        # 全屏模式下自动隐藏菜单栏（鼠标悬停顶部时显示）
        AppleMenuBarVisibleInFullscreen = false;
      };
    };

    # 注：控制中心 AirDrop/Bluetooth/NowPlaying 等多态模式（值 8）暂无上游
    # option 表达（只能 bool），KeyboardBrightness/TimeMachine/VoiceControl/Weather
    # 也暂无专用 option——等 nix-darwin 上游适配后再声明。
  };
}
