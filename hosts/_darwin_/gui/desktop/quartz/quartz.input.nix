# 输入/触控板声明（system.defaults：NSGlobalDomain + trackpad）
{
  system.defaults = {
    "NSGlobalDomain" = {
      # 句首自动大写
      "NSAutomaticCapitalizationEnabled" = true;
      # 自动句号替换
      "NSAutomaticPeriodSubstitutionEnabled" = true;
      # F1-F12 作为标准功能键
      "com.apple.keyboard.fnState" = true;
      # 轻点触控板 = 单击
      "com.apple.mouse.tapBehavior" = 1;
      # 双指点按 = 辅助点按
      "com.apple.trackpad.enableSecondaryClick" = true;
      # 指针跟踪速度 1.0
      "com.apple.trackpad.scaling" = 1.0;
      # Force Click 与触觉反馈
      "com.apple.trackpad.forceClick" = true;
      # 拖到文件夹悬停自动展开
      "com.apple.springing.enabled" = true;
      # 弹簧载入前等待 0.5s
      "com.apple.springing.delay" = 0.5;
      # 自然滚动方向
      "com.apple.swipescrolldirection" = true;
    };

    "trackpad" = {
      # 轻点来点按
      Clicking = true;
      # 禁用轻点后拖移
      Dragging = false;
      # 双指辅助点按
      TrackpadRightClick = true;
      # 禁用三指拖移
      TrackpadThreeFingerDrag = false;

      # 点按压力中等（0/1/2 = 轻/中/重）
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
      # Force Click 触觉段落反馈
      ActuateDetents = true;
      # 允许用力点按
      ForceSuppressed = false;

      # 拖移后立即释放
      DragLock = false;
      # 不用角落辅助点按
      TrackpadCornerSecondaryClick = 0;
      # 禁用三指轻点查询
      TrackpadThreeFingerTapGesture = 0;
      # 四指左右轻扫切换全屏应用/桌面空间
      TrackpadFourFingerHorizSwipeGesture = 2;
      # 四指捏合 = 启动台
      TrackpadFourFingerPinchGesture = 2;
      # 四指上下轻扫 = 调度中心
      TrackpadFourFingerVertSwipeGesture = 2;
      # 惯性滚动
      TrackpadMomentumScroll = true;
      # 双指捏合缩放
      TrackpadPinch = true;
      # 双指旋转
      TrackpadRotate = true;
      # 三指左右轻扫切换空间
      TrackpadThreeFingerHorizSwipeGesture = 2;
      # 三指上下轻扫 = 调度中心
      TrackpadThreeFingerVertSwipeGesture = 2;
      # 双指轻点两下智能缩放
      TrackpadTwoFingerDoubleTapGesture = true;
      # 右边缘双指轻扫 = 通知中心
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
    };

    # 上游暂无专用 option 的设置（CustomUserPreferences 直接写 defaults）
    "CustomUserPreferences" = {
      NSGlobalDomain = {
        # 键盘 UI 导航模式 = 1（全键盘控制）
        "AppleKeyboardUIMode" = 1;
        # 警告音不闪屏
        "com.apple.sound.beep.flash" = false;
      };
    };
  };
}
