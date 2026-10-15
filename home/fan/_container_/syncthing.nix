# syncthing（P2P 文件同步）——容器平台层公共（ide-si / ide-lenovo / ide-mac 共用一份）
#   同步：仅一个目录 —— /home/fan/Desktop/share（桌面上的 share），成员 = 现有全部机器 + 三个 ide 容器
#     （清单 tools/syncthingPeers.nix 的 peers + idePeers；不参与 ~/sync，sync 仅现有机器之间）
#   身份：syncthing 以 fan（uid 1000）运行 —— 同步进来的文件属主即 fan，桌面会话直接可读写，
#     故不再需要 root 侧挂载（原先 /root/share + root 属主文件正是权限问题之源）；
#     配置/数据/同步目录均靠 compose 挂到 fan 侧持久化（见 docker/ide/docker-compose-*.yml）
#   自启：容器 PID1 即 systemd，写 /etc/systemd/system/syncthing.service（serve 前台 + Restart=always）；
#         unit 模板见 ./syncthing.service，激活时 sed 注入 syncthing store 路径，内容不变则跳过（幂等）
#   自动注册：/usr/local/bin/syncthing-autoregister.sh（清单驱动，幂等补缺）+ oneshot unit
#     （./syncthing-autoregister.service，仍以 root 跑；因它按 $HOME 找 config.xml，其 HOME 也指 /home/fan）；
#     GUI 密码经 age 解密注入（$HOME/.secrets/age-keys.txt）
{
  pkgs,
  lib,
  tools,
  ...
}:
let
  inherit (tools.syncthingPeers) peers idePeers retired;
  peerIds = map (p: p.id) peers;
  shareIds = peerIds ++ map (p: p.id) idePeers;
  autoConfigScript = tools.syncthingAutoConfig {
    inherit pkgs peers retired;
    extraPeers = idePeers;
    folders = [
      {
        id = "share";
        label = "share";
        devices = shareIds;
        # 同步目录落点须与 compose 的 ./share 挂载点一致（桌面上的 share 目录）
        path = "/home/fan/Desktop/share";
      }
    ];
    guiPasswordAgePath = "${../../..}/secrets/syncthing-gui-password.age";
  };
in
{
  home.packages = [ pkgs.syncthing ];

  # 目录属主与进程身份都是 fan，故本激活排在 sessionUser（建 fan 用户）之后；DAG 容忍缺失名。
  home.activation.syncthingService = lib.hm.dag.entryAfter [ "writeBoundary" "sessionUser" ] ''
    # 0) 同步目录（compose 把宿主 ./share 挂在 /home/fan/Desktop/share）+ 忽略规则
    #    属主移交：顶层每次核对；整树 chown 只在顶层非 fan 时做一次 —— 迁移历史 root 属主文件，
    #    之后同步进来的文件都由 fan 版 syncthing 创建，天然 fan 属主。
    shareDir=/home/fan/Desktop/share
    chown_fan_once() {
      [ -e "$1" ] || return 0
      [ "$(stat -c %u "$1")" = "1000" ] && return 0
      chown -R fan:fan "$1" || echo "警告: chown -R $1 失败（fan 可能无写权限）"
    }
    mkdir -p "$shareDir"
    chown_fan_once "$shareDir"
    install -m 0644 -o fan -g fan ${pkgs.writeText "share-stignore" tools.syncthingStignore} "$shareDir/.stignore"
    # 配置/数据目录：原先 root 版服务写下的文件属主是 root，不移交则 fan 版写不了配置
    chown_fan_once /home/fan/.config/syncthing
    chown_fan_once /home/fan/.local/state/syncthing

    # 1) 自动注册脚本（每次激活写入，清单变更即生效）
    install -m 0755 ${pkgs.writeShellScript "syncthing-autoregister" autoConfigScript} /usr/local/bin/syncthing-autoregister.sh

    # 2) systemd unit（内容不变则跳过，幂等；变更则重启 —— 如服务身份自 root 改 fan）
    unit_changed=0
    for unit in syncthing.service syncthing-autoregister.service; do
      tmp=$(mktemp)
      sed "s|@syncthing@|${pkgs.syncthing}|" ${./.}"/$unit" > "$tmp"
      if ! cmp -s "$tmp" "/etc/systemd/system/$unit" 2>/dev/null; then
        cp "$tmp" "/etc/systemd/system/$unit"
        unit_changed=1
      fi
      rm -f "$tmp"
    done
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
    fi
    if [ "$unit_changed" = "1" ] && /usr/bin/systemctl is-active --quiet syncthing.service; then
      echo "===> syncthing unit 已变更，重启 syncthing.service"
      /usr/bin/systemctl restart syncthing.service || echo "警告: syncthing.service 重启失败（下轮 start 补）"
    fi

    # 3) 启用并确保存活（幂等）；失败输出真实错误
    if ! /usr/bin/systemctl enable syncthing.service syncthing-autoregister.service; then
      echo "警告: systemctl enable syncthing 失败（容器重启后不会自启）"
    fi
    state=$(/usr/bin/systemctl show -p ActiveState --value syncthing.service 2>/dev/null || echo unknown)
    if [ "$state" != "active" ]; then
      if /usr/bin/systemctl start syncthing.service; then
        echo "===> syncthing.service 已启动"
      else
        echo "警告: syncthing.service 启动失败，unit 状态："
        /usr/bin/systemctl status syncthing.service --no-pager -n 5 2>&1 | head -12 || true
        /usr/bin/journalctl -u syncthing.service -n 10 --no-pager 2>/dev/null || true
      fi
    fi
    # 自动注册每次激活都重跑（清单变更即生效；oneshot 幂等）
    /usr/bin/systemctl restart syncthing-autoregister.service \
      || echo "警告: syncthing-autoregister.service 触发失败（下次部署补）"
  '';
}
