#!/usr/bin/env python3
"""Bitwarden 桌面版：关闭「登录时自动启动」。

Bitwarden 每次启动都按自身状态重建 ~/.config/autostart/bitwarden.desktop
（openAtLogin 缺省 true），所以在 nix 里写 Hidden=true 的 autostart 条目会被它覆盖，
只能改它自己的状态文件。该文件是应用实体状态（electron-store 随时会重写），
故由激活脚本就地改一个键，不做 nix 链接。

键名格式见 bitwarden/clients 的 state provider：global_<stateDefinition>_<key>。
"""
import json
import os
import pathlib
import sys

KEY = "global_desktopSettings_openAtLogin"
DATA = pathlib.Path.home() / ".config/Bitwarden/data.json"
AUTOSTART = pathlib.Path.home() / ".config/autostart/bitwarden.desktop"


def disable_autostart():
    state = {}
    if DATA.exists():
        try:
            state = json.loads(DATA.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            print(f"警告: 解析 {DATA} 失败，跳过开机自启修改（{exc}）")
            return
    if not isinstance(state, dict):
        print(f"警告: {DATA} 不是对象，跳过开机自启修改")
        return
    if state.get(KEY) is not False:
        state[KEY] = False
        DATA.parent.mkdir(parents=True, exist_ok=True)
        tmp = DATA.with_name(DATA.name + ".tmp")
        # 缩进用制表符：与 electron-store 的写出一致，避免格式来回跳
        tmp.write_text(json.dumps(state, ensure_ascii=False, indent="\t"), encoding="utf-8")
        os.chmod(tmp, 0o600)
        os.replace(tmp, DATA)
        print(f"bitwarden: 已关闭开机自启（{DATA}）")
    # 撤掉条目本由 Bitwarden 在下次启动时完成，这里直接删掉，改完即刻生效
    if AUTOSTART.is_symlink() or AUTOSTART.exists():
        AUTOSTART.unlink()
        print(f"bitwarden: 已删除 {AUTOSTART}")


if __name__ == "__main__":
    sys.exit(disable_autostart())
