# agenix 解密身份（系统层）：age 私钥路径
# 与 home 层约定一致：$HOME/.secrets/age-keys.txt（secrets/README.md 有密钥生成/分发说明）
# 用户获取：darwin 用 system.primaryUser（nix-darwin 专属），NixOS 固定 fan（users/fan 定义）

{ config, lib, ... }:
let
  userName =
    if config ? system.primaryUser then config.system.primaryUser
    else "fan";
in
{
  age.identityPaths = [
    "${config.users.users.${userName}.home}/.secrets/age-keys.txt"
  ];
}
