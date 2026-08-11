# agenix 解密身份（系统层）：age 私钥路径
# 与 home 层约定一致：$HOME/.secrets/age-keys.txt（secrets/README.md 有密钥生成/分发说明）

{ config, ... }:
{
  age.identityPaths = [
    "${config.users.users.${config.system.primaryUser}.home}/.secrets/age-keys.txt"
  ];
}
