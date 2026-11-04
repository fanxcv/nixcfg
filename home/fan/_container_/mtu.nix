# 容器 eth0 MTU 固定为 1450（ide-lenovo / ide-mac 共用）
#   背景：宿主到外网（含 ai.qksxin.com 8.217.71.88）的路径 MTU 是 1450，而 Docker 给容器 veth 的默认 MTU 是 1500。
#   后果：TCP 会发 length=1448 的满段（总 1488 > 1450），被路径静默丢弃且 PMTUD 未生效，
#         客户端在同一 seq 上反复重传（1.4s→3.9s→7.8s→…），请求体永远到不齐。
#         抓包实证：seq 1:1449 length 1448 反复重发，服务端 SACK 只确认后面 114 字节的小段。
#         表现为 pi 报 "Request timed out."（带 132KB system prompt 的请求必挂），curl 偶发 0A000126。
#   实测：同一 135KB 请求，MTU 1500 时 60s 失败；改 1450 后 1.7–2.1s 成功。
#   容器重启时 Docker 会把 veth MTU 重置回 1500，故用 oneshot 服务在启动时纠正。
#   宿主侧对应改动：/etc/systemd/network/eth0.network.d/mtu.conf（MTUBytes=1450）与
#   /etc/sysctl.d/99-mtu.conf（tcp_mtu_probing=1）——宿主是 PVE 生成的 LXC，不在本仓库机器列表内，故手工维护。

{ pkgs, lib, ... }:
let
  mtu = 1450;

  mtuScript = pkgs.writeShellScript "ide-mtu" ''
    set -eu
    # nix 工具必须绝对路径（容器激活/服务的 PATH 不含 nix profile）
    ${pkgs.iproute2}/bin/ip link set eth0 mtu ${toString mtu} || {
      echo "警告: 设置 eth0 MTU ${toString mtu} 失败（容器可能非特权；网络不受影响但大请求仍会被丢）"
      exit 0
    }
    echo "[ide-mtu] eth0 MTU 已设为 ${toString mtu}"
  '';

  mtuUnit = ''
    [Unit]
    Description=Set container eth0 MTU to ${toString mtu}
    After=network-online.target
    Wants=network-online.target
    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=@mtuScript@
    [Install]
    WantedBy=multi-user.target
  '';
in
{
  home.activation.ideMtu = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 立即纠正 + 装 unit（容器重启后 Docker 会把 veth MTU 重置为 1500，由该 unit 兜底）
    ${mtuScript}
    unit=/etc/systemd/system/ide-mtu.service
    tmp=$(mktemp)
    printf '%s' '${mtuUnit}' > "$tmp"
    sed -i "s|@mtuScript@|${mtuScript}|" "$tmp"
    if ! cmp -s "$tmp" "$unit" 2>/dev/null; then
      cp "$tmp" "$unit"
    fi
    rm -f "$tmp"
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true
    /usr/bin/systemctl enable ide-mtu.service >/dev/null 2>&1 || true
  '';
}
