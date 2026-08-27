# xrdp 远程桌面（RDP 协议）——替换 krdp
# krdp 走 xdg-desktop-portal 的 RemoteDesktop.CreateSession，而 portal-kde 在 X11 会话
# 下直接返回 OtherError（error code 2，"remote desktop is not available in X11 sessions"），
# nix-pve 是 X11 会话（plasmax11，RustDesk 捕获需要）→ krdp 设计上不可用，换 xrdp。
# xrdp 会话独立（sesman 起新 Xorg :10 + startplasma-x11），与本地 SDDM 桌面（:0）并存；
# 认证走 PAM（fan 密码 hash 同 SDDM 登录）；xorgxrdp 模块路径已内嵌 xrdp 包 sesman.ini。
# 连接：mstsc/微软远程桌面 → 10.2.241.39:3389 或 tailscale IP:3389，账号 fan / 登录密码
{
  pkgs,
  lib,
  ...
}:
{
  services.xrdp = {
    enable = true;
    openFirewall = true; # nftables 放行 3389（LAN 10.2.241.39 直连）
    # KDE 桌面会话（startplasma-x11 在 /run/current-system/sw/bin，plasma6 模块提供）
    defaultWindowManager = "startplasma-x11";
  };

  # 切换瞬间 3389 可能被旧 krdp 占用（本部署同时停 krdp）→ 失败自动重试
  systemd.services.xrdp.serviceConfig.Restart = lib.mkForce "on-failure";
  systemd.services.xrdp-sesman.serviceConfig.Restart = lib.mkForce "on-failure";
}
