# RustDesk 自建中继服务器配置（macOS 三台共享）
# 只注入服务器相关字段（RustDesk2.toml 顶层的 rendezvous_server + [options] 段
# 的 key/custom-rendezvous-server/direct-server），serial/nat_type/trusted_devices
# 等运行时字段不动，避免覆盖客户端自身状态。
# 机器专属的 RustDesk.toml（ID 密钥对/密码）走 agenix，见 hosts/<host>/rustdesk.nix

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
          local f="$dir/RustDesk2.toml"
          mkdir -p "$dir"
          python3 - "$f" "${rendezvousServer}" "${serverKey}" <<'PYEOF'
    import re
    import sys

    path, rendezvous, key = sys.argv[1], sys.argv[2], sys.argv[3]

    # 目标字段：顶层 rendezvous_server；[options] 段 key/custom-rendezvous-server/direct-server
    top_updates = {"rendezvous_server": f"'{rendezvous}'"}
    opt_updates = {
        "key": f"'{key}'",
        "custom-rendezvous-server": f"'{rendezvous.split(':')[0]}'",
        "direct-server": "'Y'",
    }

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

    # 顶层字段缺失时补在文件开头
    for k, v in top_updates.items():
        out.insert(0, f"{k} = {v}")

    # [options] 字段缺失时插到该段开头；段不存在则追加到文件末尾
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
    PYEOF
          chmod 600 "$f"
        }
        setup_rustdesk_server
  '';
}
