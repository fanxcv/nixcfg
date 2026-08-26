# RustDesk 客户端（nix-pve NixOS 真机）——官方二进制包 + 自建 hbbs 服务器配置注入
# 包源：packages/rustdesk-bin.nix（GitHub release deb 解包，免源码编译；nixpkgs 的 rustdesk
#   无二进制缓存，虚拟机本地编译 ~1h）
# 与 mac 版（home/fan/_darwin_/rustdesk.nix）同一 hbbs/密钥；差异：
#   - 配置路径：Linux 版 ~/.config/rustdesk/{RustDesk2.toml,RustDesk_local.toml}
#     （mac 是 ~/Library/Preferences/com.carriez.RustDesk；1.4.x 起两平台同格式）
#   - 无 LaunchDaemon/LaunchAgent：进程由桌面（KDE 自动启动/手动）拉起，无 root 域注入
#   - trusted_devices 不预写（mac 那份是 mac 实机的设备 id；nix-pve 首次被连时 GUI 确认添加）
# 机制沿用 mac 实机验证结论：RustDesk2.toml 的 [options] 是权威（local 的 [options] 会被 GUI 启动
#   清空）；enable-udp-punch/enable-ipv6-punch 读 local → 两文件 [options] 全键双写
{ pkgs, lib, config, ... }:
let
  # 自建 hbbs 服务器（与 hbbr 同机，RustDesk 自动推断 relay；同 mac 版）
  rendezvousServer = "120.55.164.147:21116";
  # hbbs 公钥（id_ed25519.pub），加密连接用（同 mac 版）
  serverKey = "biYiu92uX5k0qOaDuhLIpVRcD0iYwqAOlSCDCR14uHg=";
in
{
  # 官方二进制包（packages/ 本地包集合，github release deb 解包；githubFetchBase 用默认=直连，包内主 URL 自带镜像不受影响）
  home.packages = [ (import ../../../packages { inherit pkgs; }).rustdesk-bin ];

  # KDE 自动启动（deb 包未带 autostart 文件）：登录后自启，替代 RustDesk 的"请求权限"（root 服务模式）
  # 注意：rustdesk-bin 跑在 buildFHSEnv 的 bwrap 沙箱里，bwrap 强制 no_new_privs → sudo setuid 失效，
  #   点"请求权限"输入密码必报 "If sudo is running in a container..."——沙箱固有限制，无解；
  #   普通用户模式远程控制完整可用，自启走 KDE autostart 即可，勿用 root 服务模式
  home.file.".config/autostart/rustdesk.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=RustDesk
    Comment=RustDesk remote desktop
    Exec=${config.home.profileDirectory}/bin/rustdesk
    X-GNOME-Autostart-enabled=true
    X-KDE-autostart-after=panel
  '';

  home.activation.setupRustDesk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_rustdesk() {
      local dir="$HOME/.config/rustdesk"
      mkdir -p "$dir"

      INJECT=/tmp/rustdesk_inject.py
      cat > "$INJECT" <<'PYEOF'
import re
import sys

rd2, rdlocal, rendezvous, key = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]


def apply_updates(path, top_updates, opt_updates):
    """幂等注入：顶层字段替换/补开头，[options] 段字段替换/补段；其余行原样保留（同 mac 版）"""
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


# RustDesk2.toml：网络 + 安全 + 常规（字段集与 mac 版一致，trusted_devices 除外）
apply_updates(
    rd2,
    {
        "rendezvous_server": f"'{rendezvous}'",      # 网络：ID 服务器
        "unlock_pin": "'''",                          # 安全：解锁 PIN（空）
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

# RustDesk_local.toml：[options] 全键双写（1.4.9 的 get_udp_punch_enabled/get_local_option 读 local，
#   且 local 无值 + 自建服务器时强制返回 N，即使 RustDesk2.toml 有 Y）
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

      ${pkgs.python3}/bin/python3 "$INJECT" "$dir/RustDesk2.toml" "$dir/RustDesk_local.toml" "${rendezvousServer}" "${serverKey}"
      chmod 600 "$dir"/RustDesk2.toml "$dir"/RustDesk_local.toml
      rm -f "$INJECT"

      # 进程在跑则重启（KDE 自动启动/手动拉起；桌面会话不在则跳过）
      # 绝对路径：hm 激活 PATH 无 python3/pkill（_common_/path.nix 只补系统路径）
      ${pkgs.procps}/bin/pkill -x rustdesk 2>/dev/null || true
      echo "[rustdesk] 配置已注入 ~/.config/rustdesk（nix-pve，hbbs ${rendezvousServer}；进程已重启或待手动启动）"
    }
    setup_rustdesk
  '';
}
