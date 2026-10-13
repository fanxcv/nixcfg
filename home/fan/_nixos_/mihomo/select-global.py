#!/usr/bin/env python3
"""mihomo 启动后把 GLOBAL 组指向延迟择优组（mode=global 的默认出口）

用法: select-global.py <config.yaml>

选组：proxy-groups 中第一个 type: url-test 的组（即延迟择优）；无则不改。
API：PUT /proxies/GLOBAL，地址取自配置的 external-controller（0.0.0.0 换 127.0.0.1）。
API 未就绪时重试；最终失败只警告（脚本恒 exit 0，不让 ExecStartPost 拖垮服务）。
"""
import json
import sys
import time
import urllib.request

import yaml

CONFIG = sys.argv[1]
RETRIES = 15


def load_config():
    with open(CONFIG, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def pick_group(data):
    for group in data.get("proxy-groups") or []:
        if isinstance(group, dict) and group.get("type") == "url-test":
            return group.get("name")
    return None


def controller_url(data):
    addr = str(data.get("external-controller") or "127.0.0.1:9090")
    return f"http://{addr.replace('0.0.0.0', '127.0.0.1')}/proxies/GLOBAL"


def main():
    data = load_config()
    name = pick_group(data)
    if not name:
        print("mihomo: 配置无 url-test 组，GLOBAL 保持默认")
        return
    url = controller_url(data)
    body = json.dumps({"name": name}).encode()
    for _ in range(RETRIES):
        try:
            req = urllib.request.Request(
                url, data=body, method="PUT", headers={"Content-Type": "application/json"}
            )
            with urllib.request.urlopen(req, timeout=3) as resp:
                if resp.status in (200, 204):
                    print(f"mihomo: GLOBAL → {name}")
                    return
        except Exception:  # noqa: BLE001 —— 未就绪/已选中，继续重试
            time.sleep(1)
    print(f"警告: GLOBAL → {name} 未生效（API 未就绪），保持现状")


if __name__ == "__main__":
    main()
