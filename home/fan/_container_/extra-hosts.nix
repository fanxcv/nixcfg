# 容器公共：内网 DNS 条目写入 /etc/hosts（ide-si / ide-lenovo 共用；替代 docker-compose extra_hosts）
# 背景：compose 注入的 hosts 修改必须重建容器；nix 激活直接写入，免重建，nix run 即生效
# 通道：activation 幂等追加 + systemd oneshot 启动自动恢复（容器重启 Docker 重写 /etc/hosts）
# 代理环境变量不在此处：ide-si 走代理（本机 sysenv.nix），lenovo 国内直连

{ pkgs, lib, ... }:
let
  # 外部 hosts（compose extra_hosts 同款：IP 域名）
  hostLines = [
    "10.1.0.30 gitlab.hczqdev.cn"
    "10.1.0.30 maven.hzdev.cn"
  ];

  # 幂等追加脚本：激活即跑 + oneshot 服务容器启动自动恢复
  hostsScript = pkgs.writeShellScript "ide-extra-hosts" ''
    set -eu
    ${lib.concatMapStringsSep "\n" (
      line: "grep -qxF '${line}' /etc/hosts || echo '${line}' >> /etc/hosts"
    ) hostLines}
  '';

  hostsUnit = ''
    [Unit]
    Description=Append ide extra hosts entries
    After=systemd-remount-fs.service
    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=@hostsScript@
    [Install]
    WantedBy=multi-user.target
  '';
in
{
  home.activation.ideExtraHosts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # hosts 幂等追加 + oneshot 服务（容器重启后 Docker 重写 /etc/hosts，启动时自动恢复）
    ${hostsScript}
    unit=/etc/systemd/system/ide-extra-hosts.service
    tmp=$(mktemp)
    printf '%s' '${hostsUnit}' > "$tmp"
    sed -i "s|@hostsScript@|${hostsScript}|" "$tmp"
    if ! cmp -s "$tmp" "$unit" 2>/dev/null; then
      cp "$tmp" "$unit"
    fi
    rm -f "$tmp"
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true
    /usr/bin/systemctl enable ide-extra-hosts.service >/dev/null 2>&1 || true
    # restart 而非 start：RemainAfterExit 下 start 对已 active 是 no-op，restart 保证激活时重跑
    /usr/bin/systemctl restart ide-extra-hosts.service >/dev/null 2>&1 || true
  '';
}
