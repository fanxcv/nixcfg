# mini-m4 SSH 身份密钥（id_rsa 对）由 nix 管理——同 ide/nix-pve host key 的 agenix 机制
#   私钥：secrets/hosts/mini-m4/ssh_id_rsa.age（加密入库，激活自动解密到 ~/.ssh/id_rsa）
#   公钥：secrets/hosts/mini-m4/ssh_id_rsa.pub（明文入库；_common_/ssh.nix 的 authorized_keys
#         追加源即此文件，原 mac-pub.pub 已退役删除）
#   本机 ~/.ssh/id_rsa 由 age.secrets 每次激活覆盖（同内容幂等），可安全删除本地手放文件
{ config, ... }:
{
  age.secrets.sshIdRsa = {
    file = ../../../secrets/hosts/mini-m4/ssh_id_rsa.age;
    path = "${config.home.homeDirectory}/.ssh/id_rsa";
    mode = "600";
  };
}
