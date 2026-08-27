# 电源计划（照搬 tsln1998/nixcfg 的 plasma.powerdevil.nix 全文）：
#   AC=performance / 电池=balanced / 低电=powerSaving；低电 20% / 危机 5% → hibernate
# 依赖：swap 8G（disks.nix 的 resumeDevice）供 hibernate；系统层无 TLP（tsln 同款）
_: {
  programs.plasma.powerdevil = {
    # 通用设置
    general = {
      # 挂起时暂停媒体播放器
      pausePlayersOnSuspend = true;
    };

    # 电池电量
    batteryLevels = {
      # 低电量临界值
      lowLevel = 20;
      # 危机电量临界值
      criticalLevel = 5;
      # 危机电量事件
      criticalAction = "hibernate";
    };

    # 交流供电
    AC = {
      powerProfile = "performance";
      powerButtonAction = "sleep";

      whenSleepingEnter = "standby";

      whenLaptopLidClosed = "sleep";
      inhibitLidActionWhenExternalMonitorConnected = true;

      keyboardBrightness = null;
      displayBrightness = null;

      autoSuspend = {
        action = "sleep";
        idleTimeout = 15 * 60;
      };

      turnOffDisplay = {
        idleTimeout = 10 * 60;
        idleTimeoutWhenLocked = 5 * 60;
      };

      dimKeyboard = {
        enable = true;
      };

      dimDisplay = {
        enable = true;
        idleTimeout = 2 * 60;
      };
    };

    # 电池供电
    battery = {
      powerProfile = "balanced";
      powerButtonAction = "sleep";

      whenSleepingEnter = "standbyThenHibernate";

      whenLaptopLidClosed = "sleep";
      inhibitLidActionWhenExternalMonitorConnected = false;

      keyboardBrightness = null;
      displayBrightness = null;

      autoSuspend = {
        action = "sleep";
        idleTimeout = 10 * 60;
      };

      turnOffDisplay = {
        idleTimeout = 5 * 60;
        idleTimeoutWhenLocked = 3 * 60;
      };

      dimKeyboard = {
        enable = true;
      };

      dimDisplay = {
        enable = true;
        idleTimeout = 2 * 60;
      };
    };

    # 低电量
    lowBattery = {
      powerProfile = "powerSaving";
      powerButtonAction = "sleep";

      whenSleepingEnter = "standbyThenHibernate";

      whenLaptopLidClosed = "sleep";
      inhibitLidActionWhenExternalMonitorConnected = false;

      keyboardBrightness = null;
      displayBrightness = 15;

      autoSuspend = {
        action = "sleep";
        idleTimeout = 5 * 60;
      };

      turnOffDisplay = {
        idleTimeout = 2 * 60;
        idleTimeoutWhenLocked = 60;
      };

      dimKeyboard = {
        enable = true;
      };

      dimDisplay = {
        enable = true;
        idleTimeout = 60;
      };
    };
  };
}
