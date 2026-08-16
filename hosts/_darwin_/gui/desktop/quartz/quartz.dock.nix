# Dock 声明（system.defaults.dock）
# persistent-apps 是 Dock 固定应用清单，与 homebrew casks（apps.nix）保持一致，按需增删
# 注意：mba-m5/mbp-m1 用机器层 lib.mkForce 覆盖本清单（hosts/<host>/dock.nix），本文件仅 mini-m4 直接生效
{
  system.defaults.dock = {
    # Dock 在屏幕左侧
    orientation = "left";
    # 应用切换器仅显示在主屏幕
    appswitcher-all-displays = false;
    # Dock 始终可见，不自动隐藏
    autohide = false;
    # 鼠标悬停放大 Dock 图标
    magnification = true;
    # Dock 图标常规尺寸 33pt
    tilesize = 33;
    # 悬停放大后 60pt
    largesize = 55;
    # 窗口最小化用神奇效果
    mineffect = "genie";
    # 不显示最近使用的应用
    show-recents = false;
    # 运行中的应用显示指示点
    show-process-indicators = true;
    # 最小化窗口保留独立缩略图
    minimize-to-application = false;
    # 右下角热区动作 = 1（禁用）
    wvous-br-corner = 14;

    # Dock 固定应用（与 apps.nix casks 对齐；Apps.app 为 macOS 26 Tahoe 启动器）
    # mba-m5/mbp-m1 覆盖为 iTerm+WeChat+QQ+Edge（hosts/<host>/dock.nix）；本清单 = mini-m4 实际生效
    persistent-apps = [
      {
        app = "/System/Applications/Apps.app";
      }
      {
        app = "/Applications/iTerm.app";
      }
      {
        app = "/Applications/Microsoft Edge.app";
      }
    ];
  };
}
