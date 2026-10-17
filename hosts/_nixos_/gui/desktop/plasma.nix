# KDE Plasma 6 桌面 + SDDM（参考 tsln minipc；面板/字体/KWin 定制在 home 层，见
# home/fan/_nixos_/gui/plasma.nix——系统层只负责桌面服务本身）
{ pkgs, lib, ... }:
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
    # 登录界面预填用户名 fan（autoLogin 关闭时兜底，仍可省一次输入）
    settings.Users.DefaultUser = "fan";
  };

  # 开机直进 fan 桌面，不再选用户/输密码（mkDefault：机器可覆盖 enable=false 关掉）
  services.displayManager.autoLogin = {
    enable = lib.mkDefault true;
    user = lib.mkDefault "fan";
  };

  # 去掉用不到的预装应用（保持精简）
  environment.plasma6.excludePackages = [
    qrca
    elisa
    discover
    khelpcenter
    plasma-browser-integration
    plasma-workspace-wallpapers
    gwenview # 图片查看器（koko 替代）
    kate # 文本编辑器（vscode 替代）
    ktexteditor # kate 的库
    krdp # RDP 远程桌面（rustdesk 替代）
    plasma-keyboard # 触摸键盘（无触摸屏）
    qtvirtualkeyboard # plasma-keyboard 依赖
    # qttools 不可排除：plasma-manager 的 panels/wallpaper 脚本依赖 qdbus（qttools 提供），
    # 排除后布局/壁纸全部静默失败（qdbus: command not found）
  ];

  environment.systemPackages = [
    koko
  ];
}
