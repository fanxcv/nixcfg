# RustDesk 客户端（nix-book 笔记本）——官方二进制包 + 自建 hbbs 服务器配置注入
# 仅作 client 远程其他机器（非被控端）：无 root 服务、无系统层 autostart（那是 nix-pve
#   server 模式配套，见 hosts/nix-pve/services/rustdesk.nix）；需要时手动启动即可
# 包源：packages/rustdesk-bin.nix（GitHub release deb 解包，免源码编译；nixpkgs 的 rustdesk
#   无二进制缓存，本地编译 ~1h）
# 与 mac 版共用 tools/rustdesk-inject.py 与 tools/config.nix.rustdesk；差异：
#   - 配置路径：Linux 版 ~/.config/rustdesk/{RustDesk2.toml,RustDesk_local.toml}
#     （mac 是 ~/Library/Preferences/com.carriez.RustDesk；1.4.x 起两平台同格式）
#   - 无 LaunchDaemon/LaunchAgent：进程由桌面（KDE 自动启动/手动）拉起，无 root 域注入
#   - trusted_devices 不预写（首次被连时 GUI 确认添加）
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

  # 注意：rustdesk-bin 跑在 buildFHSEnv 的 bwrap 沙箱里，bwrap 强制 no_new_privs → sudo setuid 失效，
  #   点"解锁安全设置"输系统密码必报 "If sudo is running in a container..."——沙箱固有限制，无解；
  #   解法：设置 unlock PIN（--pin，Nix 管理）→ GUI 解锁走 PIN 弹窗（免 sudo）；普通用户模式远程控制完整可用

  home.activation.setupRustDesk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_rustdesk() {
      local dir="$HOME/.config/rustdesk"
      mkdir -p "$dir"

      ${pkgs.python3}/bin/python3 ${injector} \
        "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" \
        --server "${rustdesk.server}" --key "${rustdesk.key}" --relay "${rustdesk.relay}" \
        ${lib.optionalString (rustdesk.unlockPin or "" != "") "--pin \"${rustdesk.unlockPin}\""}
      chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml

      # 进程未运行时 pkill 失败属幂等预期；client 模式无系统层服务，桌面会话手动启动。
      ${pkgs.procps}/bin/pkill -x rustdesk 2>/dev/null || true
      echo "[rustdesk] 配置已注入 ~/.config/rustdesk（nix-book，hbbs ${rustdesk.server}；进程已重启或待手动启动）"
    }
    setup_rustdesk
  '';
}
