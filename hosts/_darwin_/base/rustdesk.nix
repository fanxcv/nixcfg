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

{
  pkgs,
  lib,
  tools,
  ...
}:
let
  rustdesk = tools.config.rustdesk;
  injector = ../../../tools/rustdesk-inject.py;
  # Mac 实机可信设备；nix-pve 首次被连时由 GUI 确认，不预写。
  trustedDevices = "009GnjljLRT/b2k0DwCFQSXI6O";
in
{
  # 注意：nix-darwin 26.05 起自定义 system.activationScripts.<名字> 条目不再自动执行
  #   （script.text 只内联内置条目），必须挂到内置入口 extraActivation/postActivation
  # 2026-08-17 事故复盘：旧实现无条件 bootout+pkill 全家重启，注入后 GUI 未拉起 → root service
  #   成为配置权威（读 root 域失败→内存官方默认）→ 周期性把官方默认写回 fan 域，注入被抹。
  #   关键机制：GUI 在位时 service 退化为 IPC-only 不写配置；注入必须先收敛检查（已到位则不动），
  #   需注入时重启全家后必须拉起 GUI（读注入配置成为权威），service 晚于 GUI 启动退化为 IPC-only。
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    setup_rustdesk_server() {
        local dir="/Users/fan/Library/Preferences/com.carriez.RustDesk"
        local root_dir="/var/root/Library/Preferences/com.carriez.RustDesk"
        local owner="fan"
        local uid
        uid="$(id -u "$owner")"
        mkdir -p "$dir" "$root_dir"

        # 1. 收敛检查：fan 配置已是自建服务器（GUI 或注入写入）→ 已到位，完全不动
        #    （避免部署时无条件杀进程触发 service 抢写把好配置变成官方默认）
        if grep -Fq "${rustdesk.relay}" "$dir/RustDesk2.toml" 2>/dev/null; then
          echo "rustdesk: 配置已是自建服务器，跳过注入/重启"
          return 0
        fi

        # 2. 停 root service（退出时会写回内存旧配置，注入必须在 bootout 之后）
        #    bootout 失败属幂等预期（服务未注册时必失败），保留 || true
        launchctl bootout system/com.carriez.RustDesk_service 2>/dev/null || true
        sleep 1

        # 3. 注入双域——注入失败直接中断系统激活（暴露问题，无兜底）
        ${pkgs.python3}/bin/python3 ${injector} \
          "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" \
          --server "${rustdesk.server}" --key "${rustdesk.key}" --relay "${rustdesk.relay}" \
          --trusted-devices "${trustedDevices}"
        chown "$owner":staff "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
        chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
        ${pkgs.python3}/bin/python3 ${injector} \
          "$root_dir/RustDesk2.toml" "$root_dir/RustDesk_local.toml" \
          --server "${rustdesk.server}" --key "${rustdesk.key}" --relay "${rustdesk.relay}" \
          --trusted-devices "${trustedDevices}"
        chmod 600 "$root_dir"/RustDesk2.toml "$root_dir"/RustDesk_local.toml

        # 4. 杀旧进程（GUI/--server 内存里是旧配置；--server 由 LaunchAgent KeepAlive 自动拉起读新配置）
        #    清理残留 ipc socket，避免 service 误判已有实例退化为 IPC-only；pkill/rm 空转属幂等预期
        pkill -9 -f "RustDesk.app/Contents/MacOS" 2>/dev/null || true
        rm -rf /tmp/RustDesk-0 /tmp/RustDesk-501 2>/dev/null || true
        sleep 1

        # 5. 先拉起 GUI（读 fan 域注入配置成为权威；GUI 在位 → service 退化为 IPC-only）
        #    拉起失败（无 GUI 会话的 headless 场景）属预期，配置随后由 service 或下次 GUI 接管
        if [ -n "$uid" ] && [ -x /Applications/RustDesk.app/Contents/MacOS/RustDesk ]; then
          launchctl asuser "$uid" open -a RustDesk 2>/dev/null || echo "警告: RustDesk GUI 拉起失败（无 GUI 会话时属预期）"
          sleep 2
        fi

        # 6. 最后才拉起 root service（GUI 已就位 → IPC-only，不会写回覆盖注入配置）
        launchctl bootstrap system /Library/LaunchDaemons/com.carriez.RustDesk_service.plist 2>/dev/null || true
      }
      setup_rustdesk_server
  '';
}
