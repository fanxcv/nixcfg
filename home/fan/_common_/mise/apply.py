#!/usr/bin/env python3
"""mise config.toml 声明式补齐（存在补齐缺失键/保留用户值，不存在创建默认；实体可写）

用法: apply.py <目标 config.toml> <nix 模板 toml>

策略（幂等，可重复执行）：
  - 文件不存在            → 用 nix 模板整体写入（默认配置）
  - 是 symlink（旧 nix 管理态）→ 实体化：以模板内容替换（恢复可写；旧 symlink 内容本就是模板）
  - 已存在（用户真实文件）  → 逐键补齐：nix 模板指定但缺失的键，以文本形式插入对应表段
    （[tools] 段的键插入段尾、子表前；整表缺失时文件末尾追加新表块——TOML 禁止重复表
    声明，所以绝不重写用户已有表）；已存在的键——含版本不同的——一律保留用户值，
    用户内容/注释/格式原样不动
"""
import json
import os
import re
import sys
import tomllib

TARGET, TEMPLATE = sys.argv[1], sys.argv[2]


def dump_inline(v):
    """TOML 内联值序列化（标量/列表/内联表；字符串用基本字符串转义）"""
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return "[" + ", ".join(dump_inline(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {dump_inline(x)}" for k, x in v.items()) + " }"
    raise TypeError(f"unsupported type: {type(v)}")


def insert_into_table(text, table, lines):
    """把 key = value 行插入 [table] 段（段尾、子表前）；段不存在则末尾追加新表块"""
    block = "\n".join(lines)
    m = re.search(rf"^\[{re.escape(table)}\]\s*$", text, re.M)
    if m is None:
        return text.rstrip("\n") + f"\n\n[{table}]\n{block}\n"
    rest = text[m.end():]
    nxt = re.search(r"^\[", rest, re.M)  # 下一个表头（含 [table.sub] 子表）
    end = m.end() + (nxt.start() if nxt else len(rest))
    return text[:end] + f"\n{block}\n" + text[end:]


def merge_text(text, tpl):
    """返回 (补齐后全文, 缺失清单)；无缺失返回 (None, [])"""
    cur = tomllib.loads(text)
    missing = []
    out = text
    for k, v in tpl.items():
        if k == "tools":
            cur_tools = cur.get("tools") or {}
            add = {t: tv for t, tv in v.items() if t not in cur_tools}
            if add:
                out = insert_into_table(out, "tools",
                                        [f"{t} = {dump_inline(tv)}" for t, tv in add.items()])
                missing.extend(f"tools:{t}" for t in add)
        elif k not in cur:
            out = insert_into_table(out, k,
                                    [f"{ck} = {dump_inline(cv)}" for ck, cv in v.items()])
            missing.append(k)
    if not missing:
        return None, []
    return out, missing


def main():
    with open(TEMPLATE, "rb") as f:
        tpl = tomllib.load(f)

    if os.path.islink(TARGET):
        os.unlink(TARGET)
        with open(TARGET, "w") as f:
            f.write(open(TEMPLATE).read())
        print(f"mise: {TARGET} 旧 symlink 已实体化（恢复用户可写）")
        return

    if not os.path.exists(TARGET):
        with open(TARGET, "w") as f:
            f.write(open(TEMPLATE).read())
        print(f"mise: {TARGET} 不存在，已用 nix 模板创建默认")
        return

    with open(TARGET, encoding="utf-8") as f:
        text = f.read()
    merged, missing = merge_text(text, tpl)
    if merged is None:
        print(f"mise: {TARGET} 已存在且无缺失键，跳过（保留用户配置）")
        return
    with open(TARGET, "w", encoding="utf-8") as f:
        f.write(merged)
    print(f"mise: {TARGET} 补齐缺失键 [{', '.join(missing)}]（已存在键未动）")


if __name__ == "__main__":
    main()
