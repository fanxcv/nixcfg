#!/usr/bin/env python3
"""Regression test for tools/rustdesk-inject.py."""

import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

SERVER = "10.20.30.40:21116"
KEY = "test-public-key"
RELAY = "10.20.30.40"
TRUSTED_DEVICE = "test-device-id"

RD2_OPTIONS = {
    "key": KEY,
    "custom-rendezvous-server": "10.20.30.40",
    "relay-server": RELAY,
    "direct-server": "Y",
    "enable-udp-punch": "Y",
    "allow-remote-config-modification": "Y",
    "keep-awake-during-incoming-sessions": "N",
    "keep-awake-during-outgoing-sessions": "Y",
    "use-texture-render": "Y",
    "enable-check-update": "N",
    "av1-test": "Y",
}

LOCAL_OPTIONS = {
    "enable-udp-punch": "Y",
    "enable-ipv6-punch": "Y",
    "direct-server": "Y",
    "allow-remote-config-modification": "Y",
    "keep-awake-during-incoming-sessions": "N",
    "keep-awake-during-outgoing-sessions": "Y",
    "use-texture-render": "Y",
    "enable-check-update": "N",
    "av1-test": "Y",
}


def run_case(injector: Path, root: Path, trusted_devices: str | None) -> None:
    root.mkdir(parents=True)
    rd2 = root / "RustDesk2.toml"
    rdlocal = root / "RustDesk_local.toml"
    rd2.write_text("nat_type = 2\n\n[options]\nexisting = 'preserved'\n")
    rdlocal.write_text("[options]\nexisting = 'preserved'\n")

    command = [
        sys.executable,
        str(injector),
        str(rd2),
        str(rdlocal),
        "--server",
        SERVER,
        "--key",
        KEY,
        "--relay",
        RELAY,
    ]
    if trusted_devices is not None:
        command += ["--trusted-devices", trusted_devices]

    # The second run proves idempotence: duplicate TOML keys would make tomllib fail.
    subprocess.run(command, check=True)
    subprocess.run(command, check=True)

    with rd2.open("rb") as handle:
        rd2_config = tomllib.load(handle)
    with rdlocal.open("rb") as handle:
        local_config = tomllib.load(handle)

    assert rd2_config["rendezvous_server"] == SERVER
    assert rd2_config["unlock_pin"] == ""
    assert rd2_config["nat_type"] == 2
    assert rd2_config["options"]["existing"] == "preserved"
    for name, value in RD2_OPTIONS.items():
        assert rd2_config["options"][name] == value

    if trusted_devices is None:
        assert "trusted_devices" not in rd2_config
    else:
        assert rd2_config["trusted_devices"] == trusted_devices

    assert local_config["kb_layout_type"] == ""
    assert local_config["options"]["existing"] == "preserved"
    for name, value in LOCAL_OPTIONS.items():
        assert local_config["options"][name] == value


def main() -> None:
    injector = Path(sys.argv[1])
    with tempfile.TemporaryDirectory() as temporary_directory:
        root = Path(temporary_directory)
        run_case(injector, root / "mac", TRUSTED_DEVICE)
        run_case(injector, root / "nixos", None)


if __name__ == "__main__":
    main()
