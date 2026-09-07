# skemate（自研终端复用服务）——容器平台层公共（ide-si / ide-lenovo 共用一份）
#   安装：overlays/skemate.nix 提供 pkgs.skemate（官方构建，flake.lock 锁定 rev，升级 nix flake update skemate）
#   配置：Nix 不管理——宿主机 compose 挂载 ./skemate → /root/.config/skemate，
#         config.json / tunnel.yaml 等由用户在宿主机 docker/ide/skemate/ 自行维护
#   自启：容器 PID1 即 systemd，写 /etc/systemd/system/skemate.service（serve 前台 +
#         Restart=always），容器重启自动拉起；unit 模板见 ./skemate.service，
#         激活时 sed 注入 skemate store 路径，内容不变则跳过（幂等）；
#         unit 变更（skemate 升级，store 路径变）强制 restart 换新二进制；
#         unit 未变但服务挂了（崩溃循环）也自动拉起并输出 journalctl
#   last_state 由 skemate 自身维护（serve 启动/退出自动写 tunnel.yaml），Nix 不再干预
#   原在 ide-si/ide-lenovo 各一份，移入容器平台层去重（平台层即容器语义，不再需要 isContainer 门控）

{ pkgs, lib, ... }:
{
  home.packages = [ pkgs.skemate ];

  home.activation.skemateService = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    unit=/etc/systemd/system/skemate.service
    tmp=$(mktemp)
    sed "s|@skemate@|${pkgs.skemate}|" ${./skemate.service} > "$tmp"
    unit_changed=0
    if ! cmp -s "$tmp" "$unit"; then
      cp "$tmp" "$unit"
      unit_changed=1
    fi
    rm -f "$tmp"
    # 无条件：确保 systemd 认识 unit 且已启用（幂等）；失败不再静默，输出真实错误
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
    fi
    if ! /usr/bin/systemctl enable skemate.service; then
      echo "警告: systemctl enable skemate.service 失败，错误如上（容器重启后不会自启）"
    fi
    # 重启条件：unit 变更（skemate 升级，旧进程仍跑旧二进制）或服务未存活（崩溃循环）
    # 用 ActiveState 判断而非 is-active：崩溃循环时 unit 处于 auto-restart（activating），is-active 会误判为 active
    state=$(/usr/bin/systemctl show -p ActiveState --value skemate.service 2>/dev/null || echo unknown)
    if [ "$unit_changed" = "1" ] || [ "$state" != "active" ]; then
      # last_state 由 skemate 自身维护，此处只管重启
      if [ "$unit_changed" = "1" ]; then
        # 更新（store 路径变）：serve 与 agent 一起换血。agent 是 serve 用 systemd-run
        # 拉起的独立 transient 单元（skemate-agent-*），serve 重启不连带，旧 agent 会
        # 一直跑旧二进制并累积孤儿 pane。顺序：先停 serve（防其复活旧 agent）→ 杀
        # agent → 起新 serve（启动时自动从新二进制拉起新 agent）。
        /usr/bin/systemctl stop skemate.service
        /usr/bin/pkill -f "skemate agent" || true # 预期失败：agent 可能本就没在跑
        /usr/bin/systemctl start skemate.service
      else
        # 崩溃恢复：只拉起 serve，不动 agent（保留 agent 内会话）
        /usr/bin/systemctl restart skemate.service
      fi
      if /usr/bin/systemctl is-active skemate.service >/dev/null 2>&1; then
        sleep 2
        state=$(/usr/bin/systemctl show -p ActiveState --value skemate.service 2>/dev/null || echo unknown)
        if [ "$state" = "active" ]; then
          echo "===> skemate.service 已重新拉起"
        else
          echo "警告: skemate.service 拉起后未存活（当前状态 $state ，可能崩溃循环），最近日志："
          /usr/bin/journalctl -u skemate.service -n 10 --no-pager 2>/dev/null || true
        fi
      else
        echo "警告: skemate.service 启动失败（错误如上），unit 状态："
        /usr/bin/systemctl status skemate.service --no-pager -n 5 2>&1 | head -12 || true
        /usr/bin/journalctl -u skemate.service -n 10 --no-pager 2>/dev/null || true
      fi
    fi
  '';
}
