# RustDesk 机器身份（所有 Mac 通用逻辑）：ID 密钥对 + 密码，agenix 加密入库
# 每台机器各自加密一份：secrets/rustdesk.toml.<hostName>.age（密钥对是机器唯一，
# 不能共享——三台 Mac 用同一份会导致 RustDesk ID 冲突），生成方式见 secrets/README.md
# 解密到 ~/Library/Preferences/com.carriez.RustDesk/RustDesk.toml
# 服务器段（rendezvous/key）是共享配置，见 home/fan/_darwin_/rustdesk.nix
# 注意：RustDesk 运行时若改动此文件（改密码/重置密钥），需重新导出明文并 ./encrypt.sh
# 注意：加密文件必须提交 git（flake 的 self 只包含已跟踪文件，未提交则激活时找不到）

{ self, config, lib, ... }:
let
  hostName = config.networking.hostName;
  # 本机加密文件不存在时静默跳过（该机器未纳入管理，如 mba-m5/mbp-m1 尚未生成）
  secretFile = "${self}/secrets/rustdesk.toml.${hostName}.age";
in
{
  age.secrets.rustDeskToml = lib.mkIf (builtins.pathExists secretFile) {
    file = secretFile;
    path = "/Users/fan/Library/Preferences/com.carriez.RustDesk/RustDesk.toml";
    owner = "fan";
    mode = "600";
  };
}
