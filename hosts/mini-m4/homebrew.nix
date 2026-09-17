# mini-m4 专属 Homebrew 条目（cask + formula）
# 共享清单在 hosts/_darwin_/base/apps.nix
# 这里用 mkAfter 在共享清单上追加，避免全量 mkForce 重复维护

{ lib, pkgs, ... }:
{
  homebrew.casks = lib.mkAfter [
    { name = "blender"; } # 3D 建模
  ];

  # macOS 虚拟机：nixpkgs 原生包（2.36.0）。弃 cirruslabs tap——上游 tart.rb 仍用
  # depends_on :macos => :ventura 旧语法，新版 Homebrew 已禁用致 brew bundle 失败
  environment.systemPackages = [ pkgs.tart ];
}
