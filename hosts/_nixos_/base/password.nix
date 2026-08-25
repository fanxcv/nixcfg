# fan 用户密码 hash（agenix 加密；SDDM 图形登录用，SSH 走公钥）
# 明文流程：secrets/source/hosts/nix-pve/fan-password → ./secrets/encrypt.sh
# 文件本体在 hosts/nix-pve/（当前唯一 NixOS 真机；若后续新增 NixOS 机需再评估是否公共化）
{ tools, ... }:
{
  age.secrets."fan-password" = {
    file = tools.relative "secrets/hosts/nix-pve/fan-password.age";
    mode = "0400";
  };
}
