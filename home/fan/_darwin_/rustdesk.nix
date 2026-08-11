# RustDesk 客户端默认配置（macOS 三台共享）——从 mini-m4 实机导出
# 三块划分：
#   网络：RustDesk2.toml 的 rendezvous_server/custom-rendezvous-server/key/direct-server
#         + RustDesk_local.toml 的 enable-udp-punch
#   安全：RustDesk2.toml 的 unlock_pin/trusted_devices/allow-remote-config-modification
#         + RustDesk.toml 密码/身份（agenix，见 hosts/_darwin_/base/rustdesk.nix）
#   常规：RustDesk2.toml 的 keep-awake-during-incoming-sessions/av1-test
#         + RustDesk_local.toml 的 kb_layout_type/keep-awake-outgoing/use-texture-render/enable-check-update
#         + RustDesk_default.toml（view_style）与 RustDesk_hwcodec.toml（硬件编解码，整文件声明）
# 运行时字段（RustDesk2 的 nat_type/serial/local-ip-addr、local 的 remote_id/size/fav/ui_flutter）不动
# 机器专属的 RustDesk.toml（ID 密钥对/密码）走 agenix，所有 Mac 共用一份

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
        "allow-remote-config-modification": "'Y'",   # 安全：允许远程改配置
        "keep-awake-during-incoming-sessions": "'N'",  # 常规：来连时防睡眠
        "av1-test": "'Y'",                           # 常规：AV1 测试
    },
)

# RustDesk_local.toml：常规 + 网络（remote_id/size/fav/ui_flutter 运行时字段不碰）
apply_updates(
    rdlocal,
    {
        "kb_layout_type": "'''",                      # 常规：键盘布局
    },
    {
        "keep-awake-during-outgoing-sessions": "'N'",  # 常规：外连时防睡眠
        "use-texture-render": "'Y'",                 # 常规：纹理渲染
        "enable-udp-punch": "'Y'",                   # 网络：UDP 打洞
        "enable-check-update": "'N'",                # 常规：不检查更新
    },
)
PYEOF
      chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
    }
    setup_rustdesk_server
  '';

  # 纯静态配置文件整文件声明（仓库文件同步自 mini-m4 实机）
  home.file."Library/Preferences/com.carriez.RustDesk/RustDesk_default.toml".source = ./rustdesk/RustDesk_default.toml;
  home.file."Library/Preferences/com.carriez.RustDesk/RustDesk_hwcodec.toml".source = ./rustdesk/RustDesk_hwcodec.toml;
}
