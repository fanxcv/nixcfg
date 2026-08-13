# SSH host key 由 agenix 加密管理（接入时生成并加密入库，见 secrets/README.md）
# 机器名动态拼接：secrets/hosts/<hostName>/ssh_host_ed25519_key(.pub).age
{ config, tools, ... }:
{
  age.secrets."hosts/${config.networking.hostName}/ssh_host_ed25519_key" = {
    file = tools.relative "secrets/hosts/${config.networking.hostName}/ssh_host_ed25519_key.age";
    path = "/etc/ssh/keys/ssh_host_ed25519_key";
    symlink = false;
    mode = "0600";
  };
  age.secrets."hosts/${config.networking.hostName}/ssh_host_ed25519_key.pub" = {
    file = tools.relative "secrets/hosts/${config.networking.hostName}/ssh_host_ed25519_key.pub.age";
    path = "/etc/ssh/keys/ssh_host_ed25519_key.pub";
    symlink = false;
    mode = "0644";
  };
}
