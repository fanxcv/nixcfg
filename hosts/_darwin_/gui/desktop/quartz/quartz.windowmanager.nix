# 窗口管理声明（system.defaults：标签页 + 台前调度）
{
  system.defaults = {
    NSGlobalDomain = {
      # 仅全屏时自动将新窗口作为标签页
      AppleWindowTabbingMode = "fullscreen";
    };

    WindowManager = {
      # 台前调度显示同一应用的所有窗口
      AppWindowGroupingBehavior = true;
      # 台前调度不自动隐藏应用条
      AutoHide = true;
      # 点击墙纸移开窗口显示桌面
      EnableStandardClickToShowDesktop = true;
      # 平铺窗口不留边距
      EnableTiledWindowMargins = false;
      # 拖到菜单栏填满屏幕
      EnableTopTilingByEdgeDrag = true;
      # 台前调度开启（屏幕边缘应用条预览；依赖 spans-displays=false——Apple 硬性要求，见 quartz.spaces.nix）
      GloballyEnabled = true;
      # 台前调度时隐藏桌面项目（不生效时无影响）
      HideDesktop = true;
      # 台前调度时显示桌面小组件
      StageManagerHideWidgets = false;
      # 普通桌面显示小组件
      StandardHideWidgets = false;
    };

    CustomUserPreferences = {
      NSGlobalDomain = {
        # 双击标题栏不最小化
        AppleMiniaturizeOnDoubleClick = false;
      };
    };
  };
}
