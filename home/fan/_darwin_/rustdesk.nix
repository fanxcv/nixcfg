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
#   - 所有 [options] 键必须写 RustDesk2.toml：RustDesk_local.toml 的 [options] 会被 GUI 启动时清空
#   - 身份文件（RustDesk.toml）会被 1.4.9 启动时重置（外部身份注入失效，密码需 GUI 设置）
# 机器专属的 RustDesk.toml（ID 密钥对/密码）走 agenix，所有 Mac 共用一份（见 hosts/_darwin_/base/rustdesk.nix）

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
      mkdir -p "$dir"

      # 1. 停所有 RustDesk 进程：先 user 进程（GUI/--server），再 root service（bootout）
      #    root service 退出时会写回内存旧配置，所以注入必须在 bootout 之后
      pkill -9 -f "RustDesk.app/Contents/MacOS" 2>/dev/null || true
      sleep 1
      sudo -n launchctl bootout system/com.carriez.RustDesk_service 2>/dev/null || true
      sleep 1

      # 2. 注入配置（全键写 RustDesk2.toml；local 只写顶层 kb_layout_type）
      python3 - "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" "${rendezvousServer}" "${serverKey}" <<'PYEOF'
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

# RustDesk_local.toml：只写顶层 kb_layout_type（[options] 交给 GUI 自管，写入会被清空）
apply_updates(
    rdlocal,
    {
        "kb_layout_type": "'''",                      # 常规：键盘布局
    },
    {},
)
PYEOF
      chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml

      # 3. 重启：root service（读注入后的文件）+ GUI（连带拉起 --server）
      sudo -n launchctl bootstrap system /Library/LaunchDaemons/com.carriez.RustDesk_service.plist 2>/dev/null || true
      open -a RustDesk 2>/dev/null || true
    }
    setup_rustdesk_server
  '';

  # 纯静态配置文件整文件声明（仓库文件同步自 mini-m4 实机）
  home.file."Library/Preferences/com.carriez.RustDesk/RustDesk_default.toml".source = ./rustdesk/RustDesk_default.toml;
  home.file."Library/Preferences/com.carriez.RustDesk/RustDesk_hwcodec.toml".source = ./rustdesk/RustDesk_hwcodec.toml;
}
