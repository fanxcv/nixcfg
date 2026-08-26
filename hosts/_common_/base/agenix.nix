# agenix 解密身份（系统层）：age 私钥路径
# 与 home 层约定一致：$HOME/.secrets/age-keys.txt（secrets/README.md 有密钥生成/分发说明）
# 用户获取：darwin 用 system.primaryUser（nix-darwin 专属），NixOS 固定 fan（users/fan 定义）
# NixOS 注意：系统激活（agenix 解密）早于 home-manager 的 impermanence bind mount，
#   $HOME/.secrets 此时还是 tmpfs 空目录 → 私钥读不到 → 解密全失败（fan 密码/ssh key/git-credentials）
#   因此 NixOS 额外加 persist 直连路径（/persist 在 fstab 阶段已挂载，不依赖 bind mount）

{ config, lib, ... }:
let
  userName = config.system.primaryUser or "fan";
in
{
  age.identityPaths = [
    "${config.users.users.${userName}.home}/.secrets/age-keys.txt"
  ]
  ++ lib.optionals (config ? users.users.${userName}.isNormalUser) [
    # NixOS 真机：persist 直连（见上方注释）
    "/persist/home/fan/.secrets/age-keys.txt"
  ];
}
