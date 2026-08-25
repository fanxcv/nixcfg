# EdgeUpdater 系统级 LaunchDaemon 清理（系统层，root 执行）
# Edge 更新器（EdgeUpdater）安装时会注册系统级 LaunchDaemon（/Library/LaunchDaemons/com.microsoft.EdgeUpdater.*.plist），
#   用户级清理（home/fan/_darwin_/gui/apps/edge.nix）管不到 root 域 → 这里 root 直拆：
#   bootout system domain → launchctl disable 持久标记（xpc 数据库，重建 plist 也无法复活）→ 删 plist
# 配合策略 UpdateDefault=2（edge-policy.nix，禁用 Edge 自动更新）→ Edge 主程序不再拉起 updater，根治
{ lib, ... }:
{
  # nix-darwin 26.05 起自定义 system.activationScripts.<名字> 条目不再自动执行，必须挂内置入口
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    # EdgeUpdater 系统级 LaunchDaemon 清理（未注册/未加载属预期失败，|| true）
    for label in com.microsoft.EdgeUpdater.system com.microsoft.EdgeUpdater.update com.microsoft.EdgeUpdater.setup; do
      launchctl bootout "system/$label" 2>/dev/null || true # 服务未加载时 bootout 报错，属预期
      launchctl disable "system/$label" 2>/dev/null || true # 未注册时 disable 报错，属预期
      rm -f "/Library/LaunchDaemons/$label.plist"
    done
  '';
}
