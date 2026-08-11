# mini-m4 专属 Homebrew 条目（cask + formula）
# 共享清单在 hosts/_darwin_/base/apps.nix（wanted.yaml macos.all_macs.apps 维护）
# 这里用 mkAfter 在共享清单上追加，避免全量 mkForce 重复维护

{ lib, ... }:
{
  homebrew.casks = lib.mkAfter [
    { name = "jetbrains-toolbox"; } # IDE 管理器
    { name = "intellij-idea"; }     # IDEA（插件见 home/fan/mini-m4/idea.nix）
    { name = "blender"; }           # 3D 建模
  ];

  homebrew.formulae = lib.mkAfter [
    "tart" # macOS 虚拟机（cirruslabs/cli tap 由声明自动处理）
  ];
}
