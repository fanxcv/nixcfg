# KDE 锁屏（笔记本防窥）：空闲自动锁屏 + 挂起后锁屏
# nix-pve 是 VM、无合盖/挂起语义，原本未启用 → 门控排除，保持等价
{ lib, hostName, ... }:
lib.mkIf (hostName != "nix-pve") {
  programs.plasma.kscreenlocker = {
    autoLock = true; # 空闲自动锁屏（KDE 默认 5 分钟）
    lockOnResume = true; # 挂起恢复后锁屏
  };
}
