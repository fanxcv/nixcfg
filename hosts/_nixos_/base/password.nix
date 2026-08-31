# fan 用户密码 hash（agenix 加密；SDDM 图形登录用，SSH 走公钥）
# 明文流程：secrets/source/hosts/<机>/fan-password → ./secrets/encrypt.sh
# 路径按机器动态拼接（同 keys.nix 模式）；各机密码 hash 独立（secrets/source/hosts/<机>/）
# root 密码与 fan 一致（同一 hash 文件；root 默认无密码，固定后控制台/SSH root 登录可用）
{ tools, config, ... }:
{
  age.secrets."fan-password" = {
    file = tools.relative "secrets/hosts/${config.networking.hostName}/fan-password.age";
    mode = "0400";
  };

  users.users.root.hashedPasswordFile = config.age.secrets."fan-password".path;
}
