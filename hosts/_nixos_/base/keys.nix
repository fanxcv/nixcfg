# SSH host key 管理：私钥 agenix 加密（secrets/hosts/<hostName>/ssh_host_ed25519_key.age），
# 公钥明文入库（secrets/hosts/<hostName>/ssh_host_ed25519_key.pub，可直接提交 git），
# 激活时由 activationScripts 拷贝到 /etc/ssh/keys/（机器名动态拼接）
{ config, lib, tools, ... }:
{
  age.secrets."hosts/${config.networking.hostName}/ssh_host_ed25519_key" = {
    file = tools.relative "secrets/hosts/${config.networking.hostName}/ssh_host_ed25519_key.age";
    path = "/etc/ssh/keys/ssh_host_ed25519_key";
    symlink = false;
    mode = "0600";
  };

  # 公钥明文直接入库（不加密），系统层拷贝到 sshd 键目录
  system.activationScripts.sshHostKeyPub = lib.stringAfter [ "users" ] ''
    mkdir -p /etc/ssh/keys
    cp -f ${tools.relative "secrets/hosts/${config.networking.hostName}/ssh_host_ed25519_key.pub"} /etc/ssh/keys/ssh_host_ed25519_key.pub
    chmod 0644 /etc/ssh/keys/ssh_host_ed25519_key.pub
  '';
}
