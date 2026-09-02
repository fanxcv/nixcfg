# 图标 + 壁纸（tsln 母本之外 nixcfg 保留项）：主题/配色/窗口装饰已回退 catppuccin（见 ../../themes/catppuccin.nix）
# 图标：McMojave-circle（macOS 风格，packages/mcmojave-circle.nix 自打包，保留）
# 壁纸：用户图片（截图，拷入 assets/kde-wallpaper.jpg，1920x1100；preserveAspectCrop 缩放裁切填满）
# catppuccin.wallpaper 保持禁用，壁纸不走 catppuccin（见 ../../themes/catppuccin.nix）
{
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.mcmojave-circle
  ];

  programs.plasma.workspace = {
    # 图标（McMojave-circle macOS 风格）
    iconTheme = "McMojave-circle";
    # 壁纸：用户图片（截图，拷入 assets/kde-wallpaper.jpg，1920x1100；preserveAspectCrop 缩放裁切填满）
    wallpaper = ../../../../../../assets/kde-wallpaper.jpg;
    wallpaperFillMode = "preserveAspectCrop";
  };
}
