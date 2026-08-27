# KDE Plasma 6 桌面 + SDDM（参考 tsln minipc；面板/字体/KWin 定制在 home 层，见
# home/fan/_nixos_/gui/plasma.nix——系统层只负责桌面服务本身）
{ pkgs, ... }:
with pkgs;
with kdePackages;
{
  services.desktopManager.plasma6 = {
    enable = true;
    notoPackage = pkgs.noto-fonts-cjk-sans;
  };

  services.displayManager.sddm = {
    enable = true;
    enableHidpi = true;
    wayland.enable = true;
    autoNumlock = true;
  };

  # 去掉用不到的预装应用（保持精简）
  environment.plasma6.excludePackages = [
    qrca
    elisa
    discover
    khelpcenter
    plasma-browser-integration
    plasma-workspace-wallpapers
    aurorae # 窗口装饰主题引擎（默认 breeze 够用）
    gwenview # 图片查看器（koko 替代）
    kate # 文本编辑器（vscode 替代）
    ktexteditor # kate 的库
    krdp # RDP 远程桌面（rustdesk 替代）
    plasma-keyboard # 触摸键盘（无触摸屏）
    qtvirtualkeyboard # plasma-keyboard 依赖
    qttools # qdbus 等 Qt 调试工具
  ];

  environment.systemPackages = [
    koko
  ];
}
