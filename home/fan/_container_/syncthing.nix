# syncthing（P2P 文件同步）——容器平台层公共（ide-si / ide-lenovo / ide-mac 共用一份）
#   同步：仅 ~/share 一个目录（= /root/share），成员 = 现有全部机器 + 三个 ide 容器
#     （清单 tools/syncthingPeers.nix 的 peers + idePeers；不参与 ~/sync，sync 仅现有机器之间）
#   身份：以 root 运行（HM 身份；$HOME=/root），配置/数据/同步目录靠 compose 挂载持久化
#     （见 docker/ide/docker-compose-*.yml：./syncthing/config、./syncthing/state、./share）
#   自启：容器 PID1 即 systemd，写 /etc/systemd/system/syncthing.service（serve 前台 + Restart=always）；
#         unit 模板见 ./syncthing.service，激活时 sed 注入 syncthing store 路径，内容不变则跳过（幂等）
#   自动注册：/usr/local/bin/syncthing-autoregister.sh（清单驱动，幂等补缺）+ oneshot unit
#     （./syncthing-autoregister.service）；GUI 密码经 age 解密注入（$HOME/.secrets/age-keys.txt）
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
      }
    ];
    guiPasswordAgePath = "${../../..}/secrets/syncthing-gui-password.age";
  };
in
{
  home.packages = [ pkgs.syncthing ];

  # ~/share 同步目录 + 忽略规则
  home.file."share/.keep".text = "";
  home.file."share/.stignore".text = tools.syncthingStignore;

  home.activation.syncthingService = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 1) 自动注册脚本（每次激活写入，清单变更即生效）
    install -m 0755 ${pkgs.writeShellScript "syncthing-autoregister" autoConfigScript} /usr/local/bin/syncthing-autoregister.sh

    # 2) systemd unit（内容不变则跳过，幂等）
    for unit in syncthing.service syncthing-autoregister.service; do
      tmp=$(mktemp)
      sed "s|@syncthing@|${pkgs.syncthing}|" ${./.}"/$unit" > "$tmp"
      if ! cmp -s "$tmp" "/etc/systemd/system/$unit" 2>/dev/null; then
        cp "$tmp" "/etc/systemd/system/$unit"
      fi
      rm -f "$tmp"
    done
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
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
