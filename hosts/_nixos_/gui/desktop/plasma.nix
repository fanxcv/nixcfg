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
    elisa
    discover
    khelpcenter
    plasma-browser-integration
    plasma-workspace-wallpapers
  ];

  environment.systemPackages = [
    partitionmanager
  ];
}
