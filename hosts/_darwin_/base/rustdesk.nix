# RustDesk 配置注入（系统层，root 执行）——原 home/fan/_darwin_/rustdesk.nix 的 HM 激活迁移
# 架构：涉及 root 域/LaunchDaemon/跨用户进程的操作归系统激活（root 直跑，无 sudo 桥接，
#   不再需要 sudoers NOPASSWD）；fan 域配置也在此注入（写后 chown fan）。HM 层只留静态文件声明。
# 机制（1.4.9 实机验证）：
#   - RustDesk 以 root LaunchDaemon（system 域 com.carriez.RustDesk_service）+ user LaunchAgent
#     （--server）+ GUI 三进程常驻；root service 是配置权威，退出时（SIGTERM）写回内存配置
#     → 直接注入文件会被覆盖，注入必须发生在 bootout 之后
#   - GUI 会话在位时 root service 退化为 IPC-only，实际注册者是与登录用户绑定的 --server
#     （LaunchAgent KeepAlive 常驻）→ 注入登录用户域（fan）+ root 域（无 GUI 会话时的注册源）
#   - 所有 [options] 键必须写 RustDesk2.toml：RustDesk_local.toml 的 [options] 会被 GUI 启动时清空
#   - 1.4.9 的 enable-udp-punch/enable-ipv6-punch 读 RustDesk_local.toml 的 [options]，自建服务器时
#     local 无值强制 N → 两文件 [options] 全键双写

{ pkgs, ... }:
let
  # 自建 hbbs 服务器（与 hbbr 同机，RustDesk 自动推断 relay）
  rendezvousServer = "120.55.164.147:21116";
  # hbbs 公钥（id_ed25519.pub），加密连接用
  serverKey = "biYiu92uX5k0qOaDuhLIpVRcD0iYwqAOlSCDCR14uHg=";
in
{
  system.activationScripts.rustdesk = {
    text = ''
      setup_rustdesk_server() {
        local dir="/Users/fan/Library/Preferences/com.carriez.RustDesk"
        local root_dir="/var/root/Library/Preferences/com.carriez.RustDesk"
        local owner="fan"
        mkdir -p "$dir" "$root_dir"

        # 1. 停 root service（退出时会写回内存旧配置，注入必须在 bootout 之后）
        #    bootout 失败属幂等预期（服务未注册时必失败），保留 || true
        launchctl bootout system/com.carriez.RustDesk_service 2>/dev/null || true
        sleep 1

        # 2. 注入双域——注入失败直接中断系统激活（暴露问题，无兜底）
        ${pkgs.python3}/bin/python3 ${./rustdesk/inject.py} "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" "${rendezvousServer}" "${serverKey}"
        chown "$owner":staff "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
        chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
        ${pkgs.python3}/bin/python3 ${./rustdesk/inject.py} "$root_dir/RustDesk2.toml" "$root_dir/RustDesk_local.toml" "${rendezvousServer}" "${serverKey}"
        chmod 600 "$root_dir"/RustDesk2.toml "$root_dir"/RustDesk_local.toml

        # 3. 重启全部进程（pkill 跨用户需 root；--server 由 LaunchAgent KeepAlive 自动拉起并读新配置）
        #    清理残留 ipc socket，避免 service 误判已有实例退化为 IPC-only；pkill/rm 空转属幂等预期
        pkill -9 -f "RustDesk.app/Contents/MacOS" 2>/dev/null || true
        rm -rf /tmp/RustDesk-0 /tmp/RustDesk-501 2>/dev/null || true
        sleep 1
        launchctl bootstrap system /Library/LaunchDaemons/com.carriez.RustDesk_service.plist 2>/dev/null || true
      }
      setup_rustdesk_server
    '';
  };
}
