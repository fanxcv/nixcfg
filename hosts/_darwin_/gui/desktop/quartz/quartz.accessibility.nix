# 辅助功能（无障碍）
# 注：system.defaults.universalaccess.reduceMotion / reduceTransparency 在
# macOS 26 写入失败（值已移到 com.apple.Accessibility 域的 ReduceMotionEnabled /
# EnhancedBackgroundContrastEnabled）。当前期望保留系统动画和透明效果
# （即两个值均为 false），不双写 CustomUserPreferences，等上游适配后启用。
{
}
