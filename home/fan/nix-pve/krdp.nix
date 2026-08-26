# KDE RDP 远程桌面（krdp）——声明式持久化（home 层，用户域）
# 系统层（hosts/nix-pve/services/krdp.nix）已装 kdePackages.krdp + 防火墙 3389；
# 本模块负责：systemd user 服务（krdpserver 自启）+ 自签名证书（ExecStartPre 幂等生成）
# + portal 预授权（免连接确认弹窗）
# 连接：Windows mstsc → 10.2.241.39:3389 或 10.1.0.21:3389，账号 fan / 密码 QAZxsw2341
# 密码改动：改下方 ExecStart 的 -p 值（与 syncthing GUI 同款密码约定；仓库私有，明文声明）
# 注意：KCM（系统设置→远程桌面）未开，避免与 plasma-krdp_server.service 抢 3389
{ pkgs, lib, config, ... }:
{
  # home-manager 的 systemd.user.services 用 Unit/Service/Install 三段式（camelCase 键）
  systemd.user.services.krdp = {
    Unit = {
      Description = "KDE RDP server (krdpserver, 声明式)";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 5;
      # X11 会话（defaultSession=plasmax11）：krdp 自动用 X11 捕获，无需 WAYLAND_DISPLAY
      # 证书幂等生成（KCM 同款路径 ~/.local/share/krdpserver/，自签名 10 年）
      ExecStartPre = ''
        ${pkgs.bash}/bin/bash -c 'test -f %h/.local/share/krdpserver/krdp.crt || { mkdir -p %h/.local/share/krdpserver && ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -out %h/.local/share/krdpserver/krdp.crt -keyout %h/.local/share/krdpserver/krdp.key -subj /CN=nix-pve >/dev/null 2>&1; }'
      '';
      ExecStart = ''
        ${pkgs.kdePackages.krdp}/bin/krdpserver \
          --certificate %h/.local/share/krdpserver/krdp.crt \
          --certificate-key %h/.local/share/krdpserver/krdp.key \
          -u fan -p QAZxsw2341
      '';
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  # portal 预授权（免首次连接桌面确认弹窗；失败不阻断——届时桌面点确认即可）
  home.activation.setupKrdpPortal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.flatpak}/bin/flatpak permission-set kde-authorized remote-desktop org.kde.krdpserver yes \
      || echo "警告: krdp portal 预授权失败（首次连接需在桌面确认弹窗点允许）"
  '';
}
