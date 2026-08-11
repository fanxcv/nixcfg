# Dock 声明（system.defaults.dock）
# persistent-apps 是 Dock 固定应用清单，与 homebrew casks（apps.nix）保持一致，按需增删
{ config, ... }:
let
  userHome = config.users.users.${config.system.primaryUser}.home;
in
{
  system.defaults.dock = {
    # Dock 在屏幕底部
    orientation = "bottom";
    # 应用切换器仅显示在主屏幕
    appswitcher-all-displays = false;
    # Dock 始终可见，不自动隐藏
    autohide = false;
    # 鼠标悬停放大 Dock 图标
    magnification = true;
    # Dock 图标常规尺寸 44pt
    tilesize = 44;
    # 悬停放大后 58pt
    largesize = 58;
    # 窗口最小化用神奇效果
    mineffect = "genie";
    # 不显示最近使用的应用
    show-recents = false;
    # 运行中的应用显示指示点
    show-process-indicators = true;
    # 最小化窗口保留独立缩略图
    minimize-to-application = false;
    # 右下角热区动作 = 1（禁用）
    wvous-br-corner = 1;

    # Dock 固定应用（与 apps.nix casks 对齐；系统应用路径按 macOS 版本微调）
    persistent-apps = [
      {
        app = "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app";
      }
      {
        app = "/Applications/Chromium.app";
      }
      {
        app = "/Applications/QQ.app";
      }
      {
        app = "/Applications/WeChat.app";
      }
      {
        app = "/Applications/Feishu.app";
      }
      {
        app = "/Applications/Alacritty.app";
      }
      {
        app = "/Applications/Obsidian.app";
      }
      {
        app = "/Applications/Visual Studio Code.app";
      }
      {
        app = "/Applications/Cyberduck.app";
      }
      {
        app = "/Applications/TablePlus.app";
      }
    ];

    # Dock 分隔线右侧：下载目录堆栈
    persistent-others = [
      {
        folder = {
          path = "${userHome}/Downloads";
          arrangement = "date-added";  # 按加入日期排序
          displayas = "stack";         # 文件堆栈
          showas = "fan";              # 扇形展开
        };
      }
    ];
  };
}
