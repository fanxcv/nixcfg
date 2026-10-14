# SSH 用户身份公钥集合（单一事实来源）：持有身份私钥、可登录各机器的机器清单。
# 私钥加密入库 secrets/hosts/<host>/ssh-user-key.age（mac 解密为 ~/.ssh/id_rsa，nix-lenovo 为 ~/.ssh/id_ed25519）；
# 公钥明文入库 .pub，由此处汇总授权进各机器 authorized_keys（NixOS 系统层 / macOS 系统层 / 容器与服务器 home 层）。
# mba-m5 与 mbp-m1 共用同一把（fan-work-mac），列出两行只为授权集合语义完整。
# 新增机器：生成密钥对、.pub 入库后加入 hosts。
{ lib, relative }:
let
  hosts = [
    "mini-m4"
    "mba-m5"
    "mbp-m1"
    "nix-lenovo"
    "nix-asus"
  ];
in
{
  inherit hosts;
  # 去掉 .pub 尾部换行，避免 authorized_keys 里多出空行
  pubKeys = map (
    h: lib.removeSuffix "\n" (builtins.readFile (relative "secrets/hosts/${h}/ssh-user-key.pub"))
  ) hosts;
}
