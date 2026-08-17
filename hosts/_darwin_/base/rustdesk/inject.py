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
        "unlock_pin": "''",                          # 安全：解锁 PIN（空）——注意是 TOML 空字面量串（两个单引号）
        #   ⚠ 曾写成三个单引号（'''）导致整个文件 Bad TOML，RustDesk 启动读配置失败后
        #   用官方默认重建，注入全部失效（2026-08-17 事故根因，勿改回）
        "trusted_devices": "'009GnjljLRT/b2k0DwCFQSXI6O'",  # 安全：可信设备
    },
    {
        "key": f"'{key}'",                           # 网络：加密公钥
        "custom-rendezvous-server": f"'{rendezvous.split(':')[0]}'",  # 网络：自建服务器
        "relay-server": f"'{rendezvous.split(':')[0]}'",  # 网络：中继服务器（hbbr 与 hbbs 同机，同 IP；不写时 GUI 回落到官方中继）
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
        "kb_layout_type": "''",                      # 常规：键盘布局（TOML 空字面量串，两个单引号；三个单引号会 Bad TOML）
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
