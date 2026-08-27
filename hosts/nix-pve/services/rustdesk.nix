# RustDesk root 服务（--service）——声明式 systemd 服务
# 背景：GUI 内"请求权限"（解锁网络/安全配置）走 sudo 提权，而 rustdesk-bin 跑在
#   buildFHSEnv 的 bwrap 沙箱里（no_new_privs → setuid 失效）→ sudo 必失败
#   （'sudo: If sudo is running in a container...'）。root 服务预先以 root 跑，
#   客户端检测到即解锁，无需运行时提权。
# 依赖：rustdesk-bin.nix 的 extraBwrapArgs 挂载宿主 /etc（root 服务内部用
#   sudo -u <user> 降权起 user server，bwrap 默认 /etc 是 tmpfs 无 PAM → sudo 失败循环）
{ pkgs, ... }:
{
  systemd.services.rustdesk = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rustdesk-bin}/bin/rustdesk --service";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
