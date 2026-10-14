# KDE 锁屏（笔记本防窥）：空闲自动锁屏 + 挂起后锁屏
_: {
  programs.plasma.kscreenlocker = {
    autoLock = true; # 空闲自动锁屏（KDE 默认 5 分钟）
    lockOnResume = true; # 挂起恢复后锁屏
  };
}
