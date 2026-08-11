# Homebrew casks 清单（GUI 应用，三台 Mac 公共）
# 从清单移除 = 下次 darwin-rebuild 自动卸载；个别机器差异化时：
#   把该机器要增减的条目移到 hosts/<host>/homebrew.nix 用 lib.mkForce 覆盖
_: {
  homebrew.enable = true;
  homebrew.casks = [
    { name = "qq"; }
    { name = "wechat"; }
    { name = "feishu"; }
    { name = "keka"; }          # 压缩/解压
    { name = "chromium"; }
    { name = "obsidian"; }      # 笔记
    { name = "alacritty"; }     # 终端（配置见 home/fan/_darwin_/gui/apps/alacritty.nix）
    { name = "visual-studio-code"; }
    { name = "cyberduck"; }     # SFTP/FTP 客户端
    { name = "tableplus"; }     # 数据库客户端
    { name = "pearcleaner"; }   # 应用卸载清理
    { name = "keepingyouawake"; } # 防睡眠
    { name = "orbstack"; }       # 容器运行时（三台 Mac 统一）
  ];
}
