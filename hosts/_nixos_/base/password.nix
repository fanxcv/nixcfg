# fan 用户密码 hash（agenix 加密；SDDM 图形登录用，SSH 走公钥）
# 明文流程：secrets/source/fan-password → ./secrets/encrypt.sh
{ tools, ... }:
{
  age.secrets."fan-password" = {
    file = tools.relative "secrets/fan-password.age";
    mode = "0400";
  };
}
