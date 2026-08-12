# skemate（自研终端复用服务）——ide 容器专属配置
# 两台容器（lenovo-ide / si-11-ide）共用本目录（flake 均以 hostName=ide 注册，isContainer=true）
#   安装：overlays/skemate.nix 提供 pkgs.skemate（平台匹配 latest.json 官方构建）
#   配置：Nix 不管理——宿主机 compose 挂载 ./skemate → /root/.config/skemate，
#         config.json / tunnel.yaml 等由用户在宿主机 docker/ide/skemate/ 自行维护
#   自启：容器 PID1 即 systemd，写 /etc/systemd/system/skemate.service（serve 前台 +
#         Restart=always），容器重启自动拉起；unit 模板见 ./skemate.service，
#         激活时 sed 注入 skemate store 路径，内容不变则跳过（幂等）；
#         无论 unit 是否变更，激活都会检查服务存活，挂了自动重启并输出 journalctl

{ pkgs, lib, isContainer ? false, ... }:
{
  home.packages = lib.mkIf isContainer [ pkgs.skemate ];

  home.activation.skemateService = lib.mkIf isContainer (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    unit=/etc/systemd/system/skemate.service
    tmp=$(mktemp)
    sed "s|@skemate@|${pkgs.skemate}|" ${./skemate.service} > "$tmp"
    if ! cmp -s "$tmp" "$unit"; then
      cp "$tmp" "$unit"
    fi
    rm -f "$tmp"
    # 无条件：确保 systemd 认识 unit 且已启用（幂等）；失败不再静默，输出真实错误
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
    fi
    if ! /usr/bin/systemctl enable skemate.service; then
      echo "警告: systemctl enable skemate.service 失败，错误如上（容器重启后不会自启）"
    fi
    # 兜底：unit 未变但服务挂了（如崩溃循环）也尝试拉起，失败输出最近日志便于排查
    # 用 ActiveState 判断而非 is-active：崩溃循环时 unit 处于 auto-restart（activating），is-active 会误判为 active
    state=$(/usr/bin/systemctl show -p ActiveState --value skemate.service 2>/dev/null || echo unknown)
    if [ "$state" != "active" ]; then
      if /usr/bin/systemctl restart skemate.service; then
        sleep 2
        state=$(/usr/bin/systemctl show -p ActiveState --value skemate.service 2>/dev/null || echo unknown)
        if [ "$state" = "active" ]; then
          echo "===> skemate.service 已重新拉起"
        else
          echo "警告: skemate.service 拉起后未存活（当前状态 $state，可能崩溃循环），最近日志："
          /usr/bin/journalctl -u skemate.service -n 10 --no-pager 2>/dev/null || true
        fi
      else
        echo "警告: systemctl restart skemate.service 失败（错误如上），unit 状态："
        /usr/bin/systemctl status skemate.service --no-pager -n 5 2>&1 | head -12 || true
        /usr/bin/journalctl -u skemate.service -n 10 --no-pager 2>/dev/null || true
      fi
    fi
  '');
}
