# Dock 固定应用：mba-m5/mbp-m1 覆盖 quartz.dock.nix 的共享清单（去掉 Apps.app，追加 WeChat/QQ）
# 两台笔记本原各自一份逐字相同的 hosts/<机>/dock.nix，2026-09 合并至此，按 hostName 门控
# mini-m4 条件为假，仍用共享清单
{ config, lib, ... }:
{
  system.defaults.dock.persistent-apps =
    lib.mkIf (config.networking.hostName == "mba-m5" || config.networking.hostName == "mbp-m1")
      (
        lib.mkForce [
          { app = "/Applications/iTerm.app"; }
          { app = "/Applications/WeChat.app"; }
          { app = "/Applications/QQ.app"; }
          { app = "/Applications/Microsoft Edge.app"; }
        ]
      );
}
