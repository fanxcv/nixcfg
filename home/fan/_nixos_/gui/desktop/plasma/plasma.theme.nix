# KDE 主题整套（帖子方案 blog.sotkg.com/2025/08/kde-customization）
# Fedora 全局主题 + Moe 颜色/Plasma 样式 + Colloid 图标 + Hoshino 光标 + 用户壁纸 + Redmi Clock
# 包来源：moe-kde/fedora-look-and-feel/redmi-clock/hoshino-cursor 见 packages/（本地自打包）
#        colloid-icon-theme 用 nixpkgs 现成（默认安装索引名 Colloid）
# 注意：Moe 是 Plasma5 系主题（desktoptheme），KDE6 下 plasma-manager desktopTheme 可能降级/兼容
{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.moe-kde
    pkgs.fedora-look-and-feel
    pkgs.colloid-icon-theme
    pkgs.hoshino-cursor
    pkgs.redmi-clock
  ];

  programs.plasma.workspace = {
    # 全局主题（look-and-feel，Fedora）
    lookAndFeel = "org.fedoraproject.fedora.desktop";
    # 颜色方案（Moe）
    colorScheme = "Moe";
    # Plasma 外观样式（Moe desktoptheme）
    theme = "Moe";
    # 图标（Colloid 默认浅色）
    iconTheme = "Colloid";
    # 光标（Hoshino Swimsuit，X11 光标主题）
    cursor = {
      theme = "Takanashi-Hoshino-Swimsuit";
      size = 24;
    };
    # 壁纸：用户图片（截图，拷入 assets/kde-wallpaper.jpg，1920x1100；preserveAspectCrop 缩放裁切填满）
    wallpaper = ../../../../../../assets/kde-wallpaper.jpg;
    wallpaperFillMode = "preserveAspectCrop";
  };

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
