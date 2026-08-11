# 外观声明（system.defaults：固定深色）
{
  system.defaults = {
    NSGlobalDomain = {
      # 固定深色外观（不自动切换）
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
    };

    # 上游暂无专用 option 的设置
    CustomUserPreferences = {
      NSGlobalDomain = {
        # 图标/小组件着色 = 多色（macOS 26 色调选项）
        AppleIconAppearanceTintColor = "MultiColour";
        # Liquid Glass 扩散级别 0（透明玻璃默认效果）
        NSGlassDiffusionSetting = 0;
      };
    };
  };
}
