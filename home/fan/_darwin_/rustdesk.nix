# RustDesk 客户端默认配置（macOS 三台共享）——从 mini-m4 实机导出
# 三块划分：
#   网络：RustDesk2.toml 的 rendezvous_server/custom-rendezvous-server/key/direct-server
#   安全：RustDesk2.toml 的 unlock_pin/trusted_devices/allow-remote-config-modification
#   常规：RustDesk2.toml 的 keep-awake-*/av1-test/use-texture-render/enable-udp-punch/enable-check-update
# 运行时字段（nat_type/serial/local-ip-addr）与 RustDesk_local.toml（remote_id/size/fav/ui_flutter）不动
#
# 机制（1.4.9 实机验证）：
#   - RustDesk 以 root LaunchDaemon（system 域 com.carriez.RustDesk_service）+ user LaunchAgent
#     （--server）+ GUI 三进程常驻；root service 是配置权威，退出时（SIGTERM）写回内存配置
#     → 直接注入文件会被覆盖，注入必须发生在 bootout 之后
#   - GUI 会话在位时 root service 退化为 IPC-only，实际注册者是与登录用户绑定的 --server
#     （LaunchAgent KeepAlive 常驻）→ 注入登录用户域（fan）+ root 域（无 GUI 会话时的注册源）
#   - 所有 [options] 键必须写 RustDesk2.toml：RustDesk_local.toml 的 [options] 会被 GUI 启动时清空
#   - 1.4.9 的 enable-udp-punch/enable-ipv6-punch 读 RustDesk_local.toml 的 [options]，自建服务器时
#     local 无值强制 N → 两文件 [options] 全键双写

{ lib, ... }:
let
  # 自建 hbbs 服务器（与 hbbr 同机，RustDesk 自动推断 relay）
  rendezvousServer = "120.55.164.147:21116";
  # hbbs 公钥（id_ed25519.pub），加密连接用
  serverKey = "biYiu92uX5k0qOaDuhLIpVRcD0iYwqAOlSCDCR14uHg=";
in
{
  home.activation.setupRustDeskServer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_rustdesk_server() {
      local dir="$HOME/Library/Preferences/com.carriez.RustDesk"
      # 注入两域：fan（GUI/--server 会话域，实际注册者）与 /var/root（root service 域，
      #   无 GUI 会话时 service 全功能注册的配置源）。GUI 会话在位时 service 退化 IPC-only，
      #   注册者是 --server（LaunchAgent KeepAlive 常驻，读登录用户域）
      local root_dir="/var/root/Library/Preferences/com.carriez.RustDesk"
      mkdir -p "$dir"
      sudo -n mkdir -p "$root_dir" 2>/dev/null || true

      # 1. 停 root service（退出时会写回内存旧配置，注入必须在 bootout 之后）
      sudo -n launchctl bootout system/com.carriez.RustDesk_service 2>/dev/null || true
      sleep 1

      # 2. 注入脚本落盘（fan/root 域共用；顶层字段替换/补开头，[options] 段字段替换/补段，其余行原样保留）
      INJECT="/tmp/rustdesk_inject.py"
      cat > "$INJECT" <<'PYEOF'
import re
import sys

rd2, rdlocal, rendezvous, key = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]


def apply_updates(path, top_updates, opt_updates):
    """幂等注入：顶层字段替换/补开头，[options] 段字段替换/补段；其余行原样保留"""
    try:
        lines = open(path).read().splitlines()
    except FileNotFoundError:
        lines = []

    out, section = [], "top"
    for ln in lines:
        stripped = ln.strip()
        if stripped.startswith("["):
            section = stripped[1:-1]
            out.append(ln)
            continue
        m = re.match(r"^([A-Za-z0-9_-]+)\s*=", ln)
        if m and m.group(1) in (top_updates if section == "top" else opt_updates):
            target = top_updates if section == "top" else opt_updates
            out.append(f"{m.group(1)} = {target.pop(m.group(1))}")
            continue
        out.append(ln)

    for k, v in top_updates.items():
        out.insert(0, f"{k} = {v}")

    if opt_updates:
        inserted = False
        for i, ln in enumerate(out):
            if ln.strip() == "[options]":
                j = i + 1
                while j < len(out) and not out[j].strip().startswith("["):
                    j += 1
                out[j:j] = [f"{k} = {v}" for k, v in opt_updates.items()]
                inserted = True
                break
        if not inserted:
            out += ["", "[options]"] + [f"{k} = {v}" for k, v in opt_updates.items()]

    open(path, "w").write("\n".join(out) + "\n")


# RustDesk2.toml：网络 + 安全 + 常规（运行时字段 nat_type/serial/local-ip-addr 不碰）
# 1.4.9 实测：所有 [options] 键必须在这里（RustDesk_local.toml 的 [options] 会被 GUI 启动时清空）
apply_updates(
    rd2,
    {
        "rendezvous_server": f"'{rendezvous}'",      # 网络：ID 服务器
        "unlock_pin": "'''",                          # 安全：解锁 PIN（空）
        "trusted_devices": "'009GnjljLRT/b2k0DwCFQSXI6O'",  # 安全：可信设备
    },
    {
        "key": f"'{key}'",                           # 网络：加密公钥
        "custom-rendezvous-server": f"'{rendezvous.split(':')[0]}'",  # 网络：自建服务器
        "direct-server": "'Y'",                      # 网络：直连优先
        "enable-udp-punch": "'Y'",                   # 网络：UDP 打洞
        "allow-remote-config-modification": "'Y'",   # 安全：允许远程改配置
        "keep-awake-during-incoming-sessions": "'N'",  # 常规：来连时防睡眠
        "keep-awake-during-outgoing-sessions": "'Y'",  # 常规：外连时防睡眠
        "use-texture-render": "'Y'",                 # 常规：纹理渲染
        "enable-check-update": "'N'",                # 常规：不检查更新
        "av1-test": "'Y'",                           # 常规：AV1 测试
    },
)

# RustDesk_local.toml：也写 [options] 全键——1.4.9 的 get_udp_punch_enabled/get_local_option 读 local，
# 且 local 无值 + 自建服务器时强制返回 N（即使 RustDesk2.toml 有 Y）；实测 local [options] 注入后不被 GUI 清空
apply_updates(
    rdlocal,
    {
        "kb_layout_type": "'''",                      # 常规：键盘布局
    },
    {
        "enable-udp-punch": "'Y'",                   # 网络：UDP 打洞（读 local！）
        "enable-ipv6-punch": "'Y'",                  # 网络：IPv6 打洞（读 local！）
        "direct-server": "'Y'",                      # 网络：直连优先
        "allow-remote-config-modification": "'Y'",   # 安全：允许远程改配置
        "keep-awake-during-incoming-sessions": "'N'",  # 常规：来连时防睡眠
        "keep-awake-during-outgoing-sessions": "'Y'",  # 常规：外连时防睡眠
        "use-texture-render": "'Y'",                 # 常规：纹理渲染
        "enable-check-update": "'N'",                # 常规：不检查更新
        "av1-test": "'Y'",                           # 常规：AV1 测试
    },
)
PYEOF

      # 3. 注入 fan + root 域（sudo -n 依赖 sudoers NOPASSWD，激活环境已验证可用）；
      #    local 与 RustDesk2 双写：1.4.9 的 enable-udp-punch/enable-ipv6-punch 读 RustDesk_local.toml 的
      #    [options]，自建服务器时 local 无值强制 N（即使 RustDesk2.toml 有 Y）
      python3 "$INJECT" "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" "${rendezvousServer}" "${serverKey}"
      chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
      sudo -n python3 "$INJECT" "$root_dir/RustDesk2.toml" "$root_dir/RustDesk_local.toml" "${rendezvousServer}" "${serverKey}"
      sudo -n chmod 600 "$root_dir"/RustDesk2.toml "$root_dir"/RustDesk_local.toml
      rm -f "$INJECT"

      # 4. 重启全部进程：sudo pkill（root 权限，fan 版 pkill 杀不掉其他用户的进程）；
      #    --server 由 LaunchAgent KeepAlive 自动拉起并读取刚注入的登录用户域配置；
      #    清理残留 ipc socket，避免 service 误判已有实例退化为 IPC-only（不影响 --server 注册，仅求干净）
      sudo -n pkill -9 -f "RustDesk.app/Contents/MacOS" 2>/dev/null || true
      sudo -n rm -rf /tmp/RustDesk-0 /tmp/RustDesk-501 2>/dev/null || true
      sleep 1
      sudo -n launchctl bootstrap system /Library/LaunchDaemons/com.carriez.RustDesk_service.plist 2>/dev/null || true

      # 5. GUI 由用户自行打开（登录用户桌面）；--server 由 LaunchAgent 管理
    }
    setup_rustdesk_server
  '';

  # 纯静态配置文件整文件声明（RustDesk_default.toml 同步自 mini-m4 实机）
  # 注：RustDesk_hwcodec.toml 已移除静态声明——app 启动会规范化重写该文件（symlink 被覆盖成
  #   普通文件），HM 每次部署报 in-the-way 冲突；硬件编解码改由 app/GUI 自管
  home.file."Library/Preferences/com.carriez.RustDesk/RustDesk_default.toml".source = ./rustdesk/RustDesk_default.toml;
}
