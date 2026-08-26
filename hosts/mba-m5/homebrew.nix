# mba-m5 专属 Homebrew 条目（cask）
# 共享清单在 hosts/_darwin_/base/apps.nix（wanted.yaml macos.system.apps 维护）
# 这里用 mkAfter 在共享清单上追加（wanted.yaml macos.machines.mba-m5.system.apps 维护）

{ lib, ... }:
{
  homebrew.casks = lib.mkAfter [
    { name = "qq"; }                      # QQ 聊天
    { name = "wechat"; }                  # 微信
    { name = "jetbrains-toolbox"; }       # IDE 管理器
    { name = "microsoft-remote-desktop"; } # 微软远程桌面
    # ryujinx 2024-10 起被 homebrew-cask 移除（项目停更），brew bundle 无法解析会整批失败 → 已移除（wanted.yaml 同步删；如需保留改为手动装 .app，brew 不接管）
    { name = "bilibili"; }                # 哔哩哔哩
    { name = "steam"; }                   # Steam 游戏平台
  ];
}
