# mbp-m1 专属 Homebrew 条目（cask）
# 共享清单在 hosts/_darwin_/base/apps.nix（wanted.yaml macos.all_macs.apps 维护）
# 这里用 mkAfter 在共享清单上追加（wanted.yaml 的 mbp_m1.apps 维护）

{ lib, ... }:
{
  homebrew.casks = lib.mkAfter [
    { name = "wechat"; }                  # 微信（dock 固定应用需要）
    { name = "qq"; }                      # QQ 聊天（dock 固定应用需要）
    { name = "microsoft-remote-desktop"; } # Windows App（微软远程桌面）
  ];
}
