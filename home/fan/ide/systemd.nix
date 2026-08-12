# ide 容器无 user systemd：覆盖 reloadSystemd 钩子为空脚本，
# 消除每次激活的 "User systemd daemon not running. Skipping reload." 警告
# （容器只有系统级 systemd，skemate 等系统服务的启停由各自 activation 直接调 systemctl）

{ lib, ... }:
{
  home.activation.reloadSystemd = lib.mkForce (lib.hm.dag.entryAfter [ "linkGeneration" ] "");
}
