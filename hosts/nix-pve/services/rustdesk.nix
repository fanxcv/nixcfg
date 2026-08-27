# RustDesk root 服务（--service）——声明式 systemd 服务
# 背景：GUI 内"请求权限"（解锁网络/安全配置）走 sudo 提权，而 rustdesk-bin 跑在
#   buildFHSEnv 的 bwrap 沙箱里（no_new_privs → setuid 失效）→ sudo 必失败
#   （'sudo: If sudo is running in a container...'）。root 服务预先以 root 跑，
#   客户端检测到即解锁，无需运行时提权。
# 依赖：rustdesk-bin.nix 的 extraBwrapArgs 挂载宿主 /etc（root 服务内部用
#   sudo -u <user> 降权起 user server，bwrap 默认 /etc 是 tmpfs 无 PAM → sudo 失败循环）
{ pkgs, ... }:
{
  # user server（root 服务 sudo -u fan 降权起 --server）缺库根因：glibc 对 setuid
  # 程序（sudo）清 LD_LIBRARY_PATH（AT_SECURE），env_keep/-E 均无效（实测）。
  # 解法：pam_env（sudo PAM session 段，conffile=/etc/pam/environment）在 sudo 进程内
  # 注入 LD_LIBRARY_PATH（不受 AT_SECURE 影响）→ env_keep 保留 → user server 有库。
  # 单用户 VM（fan 免密 sudo）风险可接受。
  environment.etc."pam/environment".text = "LD_LIBRARY_PATH=${pkgs.rustdesk-bin.libPaths}";
  security.sudo.extraConfig = ''
    Defaults env_keep += "LD_LIBRARY_PATH"
  '';

  systemd.services.rustdesk = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rustdesk-bin}/bin/rustdesk --service";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # KDE 登录自启（系统层 /etc/xdg/autostart，不依赖 HM home.file 链接——实测 HM 的
  # ~/.config/autostart 链接会被 plasma-manager 会话清理）。前置：
  # ① SDDM 每次登录生成新 xauth（/run/user/1000/xauth_*，随机名），复制为 ~/.Xauthority
  #   （RustDesk GUI/--server 都兜底读它，缺则 X 连接失败）；② 重启 root 服务让 --server
  #   用新 key 重连 X（登录前起的 --server 拿的是旧 key/无 key）
  environment.etc."xdg/autostart/rustdesk.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=RustDesk
    Comment=RustDesk remote desktop
    Exec=sh -c "cp /run/user/1000/xauth_* /home/fan/.Xauthority 2>/dev/null; sudo systemctl restart rustdesk 2>/dev/null; exec ${pkgs.rustdesk-bin}/bin/rustdesk"
    X-GNOME-Autostart-enabled=true
    X-KDE-autostart-after=panel
  '';
}
