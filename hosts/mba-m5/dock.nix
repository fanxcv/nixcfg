# Dock 固定应用（机器专属：覆盖共享层 hosts/_darwin_/gui/desktop/quartz/quartz.dock.nix）
# mba/mbp 与 mini-m4 差异：去掉 Apps.app，追加 WeChat/QQ（mini-m4 保持共享层清单）
{ lib, ... }:
{
  system.defaults.dock.persistent-apps = lib.mkForce [
    { app = "/Applications/iTerm.app"; }
    { app = "/Applications/WeChat.app"; }
    { app = "/Applications/QQ.app"; }
    { app = "/Applications/Microsoft Edge.app"; }
  ];
}
