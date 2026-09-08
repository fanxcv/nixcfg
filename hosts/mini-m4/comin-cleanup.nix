# 一次性卸载 comin 自动部署（2026-09：mini-m4 移除 comin，仅 NixOS 真机保留）
# 任务：comin.nix 已删除；本模块仅负责把已装到实机的自管理 LaunchDaemon 卸载干净——
#   bootout + 删 plist（KeepAlive 源消失即永不自启）。幂等：未注册/不存在属预期（|| true 注释）。
{ lib, ... }:
{
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    # 卸载 comin LaunchDaemon（未注册时 print 报错属预期，|| true）
    if /bin/launchctl print system/com.github.nlewo.comin >/dev/null 2>&1; then
      /bin/launchctl bootout system/com.github.nlewo.comin 2>/dev/null || true # 已退出则 bootout 报错，幂等预期
    fi
    rm -f /Library/LaunchDaemons/com.github.nlewo.comin.plist
    echo "comin: mini-m4 的 comin LaunchDaemon 已卸载（自动部署移除，仅 NixOS 保留）"
  '';
}
