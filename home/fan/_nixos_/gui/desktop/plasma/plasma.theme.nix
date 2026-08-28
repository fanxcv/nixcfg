# KDE 主题整套：MacTahoe 全系（macOS Tahoe 风格）——全局主题/颜色/Plasma 样式/窗口装饰/欢迎屏幕（splash 随 look-and-feel）
# 叠加变更：McMojave-circle 图标 + 默认光标 + 用户壁纸 + Redmi Clock + 上下双面板（见 plasma.panels.nix）
# macOS 化：MacTahoe aurorae 装饰自带红绿灯（左置）+ 圆角 + 毛玻璃标题栏；kwin blur 效果 + 最大化无边框
# GTK 应用（Firefox 等）用 MacTahoe GTK 主题；Catppuccin KDE（Classic+Modern）已装备用（不启用）
# 包来源：mactahoe-kde/mactahoe-gtk/catppuccin-kde/mcmojave-circle/mcmojave-kde/redmi-clock 见 packages/（本地自打包）
#        numix-icon-theme-circle 用 nixpkgs 现成（备用图标）
{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.mactahoe-kde
    pkgs.mactahoe-gtk
    pkgs.catppuccin-kde
    pkgs.mcmojave-circle
    pkgs.mcmojave-kde
    pkgs.numix-icon-theme-circle
    pkgs.redmi-clock
    pkgs.qt6.qttools # qdbus：plasma-manager desktopScript 执行依赖（KDE 会话 PATH 默认无 qdbus，qdbus 在 qttools 包）
    pkgs.python3 # Panel-colorizer 插件运行时（service.py 调 python3，plasmashell PATH 默认无）
  ];

  programs.plasma.workspace = {
    # 全局主题（look-and-feel，MacTahoe macOS Tahoe 风格；splash 欢迎屏幕随主题自带）
    lookAndFeel = "com.github.vinceliuice.MacTahoe-Dark";
    # 颜色方案（MacTahoe Dark）
    colorScheme = "MacTahoeDark";
    # Plasma 外观样式（MacTahoe desktoptheme）
    theme = "MacTahoe-Dark";
    # 图标（McMojave-circle macOS 风格；numix-circle 已装可手动切）
    iconTheme = "McMojave-circle";
    # 壁纸：用户图片（截图，拷入 assets/kde-wallpaper.jpg，1920x1100；preserveAspectCrop 缩放裁切填满）
    wallpaper = ../../../../../../assets/kde-wallpaper.jpg;
    wallpaperFillMode = "preserveAspectCrop";
  };

  # macOS 化窗口：MacTahoe aurorae 装饰（红绿灯+圆角+毛玻璃，装饰自带，无需额外圆角效果）+ blur + 最大化无边框
  programs.plasma.kwin = {
    # 红绿灯按钮（mac 顺序：红关闭/黄最小化/绿最大化，左置）
    titlebarButtons.left = [ "close" "minimize" "maximize" ];
    # 最大化无边框（mac 风格）
    borderlessMaximizedWindows = true;
    # 毛玻璃：窗口半透明时背景模糊
    effects.blur.enable = true;
  };

  # 窗口装饰：MacTahoe aurorae（kwinrc 的 org.kde.kdecoration2）
  # kwin 6 的 aurorae SVG 主题名须带 __aurorae__svg__ 前缀（kwin 自动迁移 library 到 aurorae.v2）
  programs.plasma.configFile."kwinrc" = {
    "org.kde.kdecoration2" = {
      library = "org.kde.kwin.aurorae";
      theme = "__aurorae__svg__MacTahoe-Dark";
    };
  };

  # GTK 应用（Firefox/Thunderbird 等）用 MacTahoe 主题
  gtk.theme = "MacTahoe-Dark";

  # 桌面时钟（帖子方案：Redmi Clock 放桌面，非面板）
  programs.plasma.desktop.widgets = [
    {
      name = "Redmi.Clock";
      position = {
        horizontal = 960;   # 1920 屏居中（像素）
        vertical = 216;     # 距顶 20%
      };
      size = {
        width = 300;
        height = 300;
      };
    }
  ];
}
