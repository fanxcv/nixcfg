# 系统更新：不自动安装 macOS 大版本更新，由用户手动决定；安全更新自动装
{
  system.defaults.SoftwareUpdate = {
    AutomaticallyInstallMacOSUpdates = false;
  };
  # CriticalUpdateInstall 不在 nix-darwin 选项集，走 CustomSystemPreferences 写 com.apple.SoftwareUpdate 域
  system.defaults.CustomSystemPreferences."com.apple.SoftwareUpdate" = {
    CriticalUpdateInstall = true; # 安全补丁/关键更新自动安装
  };
}
