# ide 容器配置自动部署（pull 轮询模型，轻量替代 comin）
#   触发：systemd timer 每 60s 跑一次（OnBootSec=60 延迟启动，Persistent 补跑；与 comin 默认轮询周期一致）
#   逻辑：/root/nixcfg（compose bind mount，不 clone）git pull --ff-only → HEAD 变更才 nix run .#<hostName>
#   状态：/var/lib/ide-auto-deploy/last 记录上次激活 commit；容器重建后清空 → 首次轮询自动激活
#   代理：ide-si 的 all_proxy 由 sysenv.nix 写 /etc/environment.d/zz-ide-proxy.conf；environment.d 只对 user
#     实例生效（系统服务不读），unit 用 EnvironmentFile=- 显式引用（- 容忍 lenovo 无此文件），nix/libcurl 自动走代理
#   失败重试：激活失败不更新 last，下次轮询自动重试
#   为什么不用 comin：comin 只认 nixosConfigurations/darwinConfigurations 输出（deployment 固定
#     switch-to-configuration），不支持 homeConfigurations/任意命令，且 services.comin 需 NixOS/darwin 系统

{ lib, hostName, ... }:
{
  home.activation.setupIdeAutoDeploy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 1) 轮询脚本（sed 注入 hostName）
    script=/usr/local/bin/ide-auto-deploy.sh
    tmp=$(mktemp)
    sed "s|@hostName@|${hostName}|" ${./ide-auto-deploy.sh} > "$tmp"
    install -m 0755 "$tmp" "$script"
    rm -f "$tmp"

    # 2) systemd unit + timer（内容不变则跳过，幂等）
    for unit in ide-auto-deploy.service ide-auto-deploy.timer; do
      tmp=$(mktemp)
      cp ${./.}"/$unit" "$tmp"
      if ! cmp -s "$tmp" "/etc/systemd/system/$unit" 2>/dev/null; then
        cp "$tmp" "/etc/systemd/system/$unit"
      fi
      rm -f "$tmp"
    done
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true

    # 3) 启用并启动 timer（幂等）；失败输出真实错误
    if ! /usr/bin/systemctl enable ide-auto-deploy.timer; then
      echo "警告: systemctl enable ide-auto-deploy.timer 失败（容器重启后不会自动轮询）"
    fi
    if ! /usr/bin/systemctl start ide-auto-deploy.timer; then
      echo "警告: systemctl start ide-auto-deploy.timer 失败，错误如上"
    fi
    state=$(/usr/bin/systemctl is-active ide-auto-deploy.timer 2>/dev/null || echo unknown)
    echo "[ide-auto-deploy] timer 状态: $state （每 60s 轮询 /root/nixcfg，HEAD 变更自动 nix run .#${hostName}）"
  '';
}
