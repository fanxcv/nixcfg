# skemate（自研终端复用服务）——ide 容器专属配置
# 两台容器（lenovo-ide / si-11-ide）共用本目录（flake 均以 hostName=ide 注册，isContainer=true）
#   安装：overlays/skemate.nix 提供 pkgs.skemate（平台匹配 latest.json 官方构建）
#   配置：Nix 不管理——宿主机 compose 挂载 ./skemate → /root/.config/skemate，
#         config.json / tunnel.yaml 等由用户在宿主机 docker/ide/skemate/ 自行维护
#   自启：容器 PID1 即 systemd，写 /etc/systemd/system/skemate.service（serve 前台 +
#         Restart=always），容器重启自动拉起；unit 模板见 ./skemate.service，
#         激活时 sed 注入 skemate store 路径，内容不变则跳过（幂等）

{ pkgs, lib, isContainer ? false, ... }:
{
  home.packages = lib.mkIf isContainer [ pkgs.skemate ];

  home.activation.skemateService = lib.mkIf isContainer (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    unit=/etc/systemd/system/skemate.service
    tmp=$(mktemp)
    sed "s|@skemate@|${pkgs.skemate}|" ${./skemate.service} > "$tmp"
    if ! cmp -s "$tmp" "$unit"; then
      cp "$tmp" "$unit"
      systemctl daemon-reload >/dev/null 2>&1 || true
      systemctl enable skemate.service >/dev/null 2>&1 || true
      systemctl restart skemate.service >/dev/null 2>&1 \
        || echo "警告: skemate.service 启动失败，请 systemctl status skemate 查看"
    fi
    rm -f "$tmp"
  '');
}
