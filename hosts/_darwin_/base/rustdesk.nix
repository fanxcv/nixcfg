# RustDesk 机器身份（所有 Mac 共用一份）：ID 密钥对 + 密码，agenix 加密入库
# 三台 Mac 共用一个身份（用户确认：终极配置是所有机器共用）
# 解密到 ~/Library/Preferences/com.carriez.RustDesk/RustDesk.toml
# 服务器段（rendezvous/key）见 home/fan/_darwin_/rustdesk.nix
# 注意：RustDesk 运行时若改动此文件（改密码/重置密钥），需重新导出明文并 ./encrypt.sh
# 注意：加密文件必须提交 git（flake 的 self 只包含已跟踪文件）

{ self, config, ... }:
{
  age.secrets.rustDeskToml = {
    file = "${self}/secrets/rustdesk.toml.age";
    path = "/Users/fan/Library/Preferences/com.carriez.RustDesk/RustDesk.toml";
    owner = config.users.users.fan.name;
    mode = "600";
  };
}
