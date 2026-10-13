#!/usr/bin/env python3
"""mihomo 声明式配置生成（NixOS：nix-pve / nix-lenovo 共享，激活期执行）

用法: apply.py <订阅URL> <本地偏好YAML> <UI目录> <输出配置>

合并（纯文本块拼接，保留双方注释；本地文件含重复 anchor，YAML 解析器会拒收）：
  订阅为基；本地偏好中除 proxies / proxy-groups / rules 外的键覆盖订阅同名键
  （节点与分流规则取订阅，dns / sniffer / external-controller / geox-url … 取本地），
  本地独有、订阅没有的键追加到末尾。

本地偏好不是拿来即用的三处修正：
  mode         本地 rule  → global（全局模式，出口由 GLOBAL 组决定，见 select-global.py）
  external-ui  本地 ./ui  → 绝对路径指向 nix 打包的 zashboard，并删 external-ui-url
               （否则内核会往只读 store 目录下载解压）
  dns.listen   本地 :53   → 127.0.0.1:1053（<1024 端口需 root，fan 身份的用户服务绑不上；
               内核内部解析不依赖该监听，它只对外提供 DNS 服务）

失败策略：订阅下载失败一律警告并保留现有配置（不阻断 home 激活——激活还管着大量无关内容）；
首次且无现有配置时同样只警告，mihomo 服务会因缺配置起不来，重跑部署即可。
"""
import os
import re
import sys
import urllib.request

SUB_URL, LOCAL_YAML, UI_DIR, OUT = sys.argv[1:5]
SUB_KEYS = ("proxies", "proxy-groups", "rules")
DNS_LISTEN = "127.0.0.1:1053"
TOP_KEY = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*):")
# 订阅服务按 UA 分发：ClashX 的 UA 才返回 Clash YAML，其他 UA 拿到 base64 节点列表
SUB_UA = "ClashX/1.4.43"


def fetch_subscription():
    req = urllib.request.Request(SUB_URL, headers={"User-Agent": SUB_UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        text = resp.read().decode("utf-8")
    if "proxies:" not in text:
        raise ValueError("订阅未返回 Clash 配置（UA 未被识别？）")
    return text


def split_blocks(text):
    """按顶层键切块（行首无缩进的 key:）；缩进续行、空行、注释归上一块。"""
    blocks = []
    for line in text.splitlines():
        match = TOP_KEY.match(line)
        if match:
            blocks.append((match.group(1), [line]))
        elif blocks:
            blocks[-1][1].append(line)
    return blocks


def merge(sub_text, local_text):
    sub_blocks = split_blocks(sub_text)
    local_blocks = dict(split_blocks(local_text))
    lines = []
    for key, block in sub_blocks:
        # 三键取订阅；其余键本地有则覆盖，没有则用订阅的
        lines += block if key in SUB_KEYS else local_blocks.get(key, block)
    sub_keys = {key for key, _ in sub_blocks}
    for key, block in split_blocks(local_text):
        if key not in sub_keys:
            lines.append("")
            lines += block
    return "\n".join(lines) + "\n"


def patch(text):
    # 本地 rule → global：出口由 GLOBAL 组决定（见 select-global.py）
    text = re.sub(r"(?m)^mode:.*$", "mode: global", text, count=1)
    # UI 改绝对路径指向 nix 打包的 zashboard；去掉自动下载（否则内核往只读 store 目录解压）
    if re.search(r"(?m)^external-ui:", text):
        text = re.sub(r"(?m)^external-ui:.*$", f"external-ui: {UI_DIR}", text, count=1)
    else:
        text += f"external-ui: {UI_DIR}\n"
    text = re.sub(r"(?m)^external-ui-url:.*\n?", "", text)
    # :53 需 root（fan 身份用户服务绑不上）→ 高位端口
    text = text.replace("listen: :53", f"listen: {DNS_LISTEN}")
    return text


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    try:
        sub_text = fetch_subscription()
    except Exception as exc:  # noqa: BLE001 —— 网络失败不阻断部署
        print(f"警告: 订阅下载失败，保留现有配置（重跑部署可重试）：{exc}")
        return
    with open(LOCAL_YAML, encoding="utf-8") as f:
        local_text = f.read()
    text = patch(merge(sub_text, local_text))
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, OUT)
    print(f"mihomo: 配置已生成（{len(text)} 字节，mode=global，UI={UI_DIR}）")


if __name__ == "__main__":
    main()
