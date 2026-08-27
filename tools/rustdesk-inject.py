#!/usr/bin/env python3
"""Idempotently inject shared RustDesk client settings into both TOML files."""

import argparse
import re
from pathlib import Path


def apply_updates(path: Path, top_updates: dict[str, str], opt_updates: dict[str, str]) -> None:
    """Replace or add selected fields while preserving unrelated RustDesk state."""
    try:
        lines = path.read_text().splitlines()
    except FileNotFoundError:
        lines = []

    out: list[str] = []
    section = "top"
    pending_top = dict(top_updates)
    pending_options = dict(opt_updates)

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("["):
            section = stripped[1:-1]
            out.append(line)
            continue

        match = re.match(r"^([A-Za-z0-9_-]+)\s*=", line)
        if section == "top":
            target = pending_top
        elif section == "options":
            target = pending_options
        else:
            target = {}
        if match and match.group(1) in target:
            key = match.group(1)
            out.append(f"{key} = {target.pop(key)}")
            continue
        out.append(line)

    for key, value in pending_top.items():
        out.insert(0, f"{key} = {value}")

    if pending_options:
        for index, line in enumerate(out):
            if line.strip() != "[options]":
                continue
            insert_at = index + 1
            while insert_at < len(out) and not out[insert_at].strip().startswith("["):
                insert_at += 1
            out[insert_at:insert_at] = [
                f"{key} = {value}" for key, value in pending_options.items()
            ]
            break
        else:
            out += ["", "[options]"] + [
                f"{key} = {value}" for key, value in pending_options.items()
            ]

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(out) + "\n")


def server_host(server: str) -> str:
    """Strip the rendezvous port while retaining bracketed IPv6 compatibility."""
    if server.startswith("["):
        return server[1 : server.index("]")]
    return server.rsplit(":", 1)[0] if ":" in server else server


def inject(
    rd2: Path,
    rdlocal: Path,
    server: str,
    key: str,
    relay: str | None,
    trusted_devices: str | None,
) -> None:
    top_updates = {
        "rendezvous_server": repr(server),
    }
    # unlock_pin 不在 top_updates：保留用户 GUI 设置（原强制写 '' 会在每次部署清掉
    #   用户 PIN → GUI 解锁走 sudo（bwrap 沙箱 no_new_privs 必败））；行缺失时 RustDesk 读空，无碍
    if trusted_devices is not None:
        top_updates["trusted_devices"] = repr(trusted_devices)

    rd2_options = {
        "key": repr(key),
        "custom-rendezvous-server": repr(server_host(server)),
        "direct-server": "'Y'",
        "enable-udp-punch": "'Y'",
        "allow-remote-config-modification": "'Y'",
        "keep-awake-during-incoming-sessions": "'N'",
        "keep-awake-during-outgoing-sessions": "'Y'",
        "use-texture-render": "'Y'",
        "enable-check-update": "'N'",
        "av1-test": "'Y'",
    }
    if relay is not None:
        rd2_options["relay-server"] = repr(relay)

    apply_updates(rd2, top_updates, rd2_options)
    apply_updates(
        rdlocal,
        {
            # Same Bad TOML constraint as unlock_pin above.
            "kb_layout_type": "''",
        },
        {
            "enable-udp-punch": "'Y'",
            "enable-ipv6-punch": "'Y'",
            "direct-server": "'Y'",
            "allow-remote-config-modification": "'Y'",
            "keep-awake-during-incoming-sessions": "'N'",
            "keep-awake-during-outgoing-sessions": "'Y'",
            "use-texture-render": "'Y'",
            "enable-check-update": "'N'",
            "av1-test": "'Y'",
        },
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rd2", type=Path, help="RustDesk2.toml path")
    parser.add_argument("rdlocal", type=Path, help="RustDesk_local.toml path")
    parser.add_argument("--server", required=True, help="hbbs rendezvous host:port")
    parser.add_argument("--key", required=True, help="hbbs public key")
    parser.add_argument("--relay", help="optional hbbr relay host")
    parser.add_argument(
        "--trusted-devices",
        help="optional RustDesk trusted_devices value (Mac-specific in nixcfg)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    inject(
        args.rd2,
        args.rdlocal,
        args.server,
        args.key,
        args.relay,
        args.trusted_devices,
    )


if __name__ == "__main__":
    main()
