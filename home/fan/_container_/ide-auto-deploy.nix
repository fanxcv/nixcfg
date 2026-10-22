# ide 容器配置自动部署（pull 轮询模型，轻量自建）
#   触发：systemd timer 每 60s 跑一次（OnBootSec=60 延迟启动，Persistent 补跑）
#   逻辑：/root/nixcfg（compose bind mount，不 clone）fetch origin/main → 与 last 记录的 commit 比对，
#     不一致则强切 main 到 origin/main → nix run .#<hostName>
#   分支无关：不管容器内当前停在哪个分支（test 等），一律以 origin/main 为准强切（宿主工作树，分支由脚本接管）
#   状态：/var/lib/ide-auto-deploy/last 记录上次部署的 origin/main commit；容器重建后清空 → 首次轮询自动部署
#   代理：ide-si 的 all_proxy 由 sysenv.nix 写 /etc/environment.d/zz-ide-proxy.conf；environment.d 只对 user
#     实例生效（系统服务不读），unit 用 EnvironmentFile=- 显式引用（- 容忍 lenovo 无此文件），nix/libcurl 自动走代理
#   失败重试：激活失败不更新 last，下次轮询自动重试
#   为什么自研：现成系统级部署器只认 nixos/darwin 系统配置输出
#     （deployment 固定 switch-to-configuration），不支持 homeConfigurations/任意命令

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
    echo "[ide-auto-deploy] timer 状态: $state （每 60s 轮询 /root/nixcfg，origin/main 变更自动强切并 nix run .#${hostName}）"
  '';
}
