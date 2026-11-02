# KDE Plasma 6 桌面 + SDDM（参考 tsln minipc；面板/字体/KWin 定制在 home 层，见
# home/fan/_nixos_/gui/desktop/plasma/——系统层只负责桌面服务本身）
{ pkgs, lib, ... }:
with pkgs;
with kdePackages;
{
  services = {
    desktopManager.plasma6 = {
      enable = true;
      notoPackage = pkgs.noto-fonts-cjk-sans;
    };

    displayManager = {
      sddm = {
        enable = true;
        enableHidpi = true;
        wayland.enable = true;
        autoNumlock = true;
        # 登录界面预填用户名 fan（autoLogin 关闭时兜底，仍可省一次输入）
        settings.Users.DefaultUser = "fan";
      };

      # 开机直进 fan 桌面，不再选用户/输密码（mkDefault：机器可覆盖 enable=false 关掉）
      autoLogin = {
        enable = lib.mkDefault true;
        user = lib.mkDefault "fan";
      };
    };
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

    # 截图链路（微信/QQ 自带截图在 KWin Wayland 下无捕获后端，按下即崩）：
    #   Ctrl+Alt+A → Spectacle 区域截图 → 直接进剪贴板 → 聊天框 Ctrl+V。
    # 快捷键的声明式覆盖在 home 层 plasma.shortcuts.nix；微信侧已由用户释放该键。
    # 必须放系统数据目录 share/kglobalaccel（KGlobalAccel 只扫 XDG_DATA_DIRS）；
    # X-KDE-GlobalShortcutType=Service 表示“命令型”组件，无需应用常驻即可触发。
    (pkgs.writeTextDir "share/kglobalaccel/spectacle-region.desktop" ''
      [Desktop Entry]
      Type=Application
      Name=Spectacle Region to Clipboard
      NoDisplay=true
      StartupNotify=false
      Actions=spectacle-region
      X-KDE-GlobalShortcutType=Service
      X-KDE-Shortcuts=Ctrl+Alt+A

      [Desktop Action spectacle-region]
      Name=区域截图到剪贴板
      Exec=${kdePackages.spectacle}/bin/spectacle --region --background --nonotify --copy-image
      X-KDE-Shortcuts=Ctrl+Alt+A
    '')
  ];
}
