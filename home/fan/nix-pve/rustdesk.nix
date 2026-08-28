# RustDesk 客户端（nix-pve NixOS 真机）——官方二进制包 + 自建 hbbs 服务器配置注入
# 包源：packages/rustdesk-bin.nix（GitHub release deb 解包，免源码编译；nixpkgs 的 rustdesk
#   无二进制缓存，虚拟机本地编译 ~1h）
# 与 mac 版共用 tools/rustdesk-inject.py 与 tools/config.nix.rustdesk；差异：
#   - 配置路径：Linux 版 ~/.config/rustdesk/{RustDesk2.toml,RustDesk_local.toml}
#     （mac 是 ~/Library/Preferences/com.carriez.RustDesk；1.4.x 起两平台同格式）
#   - 无 LaunchDaemon/LaunchAgent：进程由桌面（KDE 自动启动/手动）拉起，无 root 域注入
#   - trusted_devices 不预写（mac 那份是 mac 实机的设备 id；nix-pve 首次被连时 GUI 确认添加）
# 机制沿用 mac 实机验证结论：RustDesk2.toml 的 [options] 是权威；
#   enable-udp-punch/enable-ipv6-punch 读 local → 两文件 [options] 全键双写
{
  pkgs,
  lib,
  config,
  tools,
  ...
}:
let
  rustdesk = tools.config.rustdesk;
  injector = ../../../tools/rustdesk-inject.py;
in
{
  # 官方二进制包（packages/ 本地包集合，github release deb 解包；githubFetchBase 用默认=直连，包内主 URL 自带镜像不受影响）
  home.packages = [ pkgs.rustdesk-bin ];

  # KDE 自动启动改系统层 /etc/xdg/autostart（见 hosts/nix-pve/services/rustdesk.nix）：
  #   HM 的 home.file 链接 ~/.config/autostart/ 会被 plasma-manager 会话清理，链接不稳定
  # 注意：rustdesk-bin 跑在 buildFHSEnv 的 bwrap 沙箱里，bwrap 强制 no_new_privs → sudo setuid 失效，
  #   点"解锁安全设置"输系统密码必报 "If sudo is running in a container..."——沙箱固有限制，无解；
  #   解法：设置 unlock PIN（--pin，Nix 管理）→ GUI 解锁走 PIN 弹窗（免 sudo）；普通用户模式远程控制完整可用，
  #   自启走 KDE autostart 即可，勿用 root 服务模式

  home.activation.setupRustDesk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_rustdesk() {
      local dir="$HOME/.config/rustdesk"
      mkdir -p "$dir"

      ${pkgs.python3}/bin/python3 ${injector} \
        "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" \
        --server "${rustdesk.server}" --key "${rustdesk.key}" --relay "${rustdesk.relay}" \
        ${lib.optionalString (rustdesk.unlockPin or "" != "") "--pin \"${rustdesk.unlockPin}\""}
      chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml

      # 进程未运行时 pkill 失败属幂等预期；root 服务（systemd Restart=on-failure）与
      # GUI（systemd user service，见 hosts/nix-pve/services/rustdesk.nix）均有守护，
      # 被杀后 5s 自动复活，配置注入即时生效。
      ${pkgs.procps}/bin/pkill -x rustdesk 2>/dev/null || true
      echo "[rustdesk] 配置已注入 ~/.config/rustdesk（nix-pve，hbbs ${rustdesk.server}；进程已重启或待手动启动）"
    }
    setup_rustdesk
  '';
}
