# mba-m5 SSH 身份密钥（id_rsa 对）由 nix 管理——mba-m5 / mbp-m1 共用同一套身份
#   私钥：secrets/hosts/mba-m5/ssh_id_rsa.age（加密入库，激活自动解密到 ~/.ssh/id_rsa）
#   公钥：secrets/hosts/mba-m5/ssh_id_rsa.pub（明文入库，_common_/ssh.nix authorized_keys 追加源）
#   覆盖语义同 mini-m4：每次激活 age -d 覆盖（同内容幂等），可安全删除本地手放文件
#   加密命令：cp ~/.ssh/id_rsa secrets/source/hosts/mba-m5/ssh_id_rsa && ./secrets/encrypt.sh
{ pkgs, lib, config, ... }:
{
  # 统一 secrets 架构（见 _common_/secrets.nix）：activation 直接 age -d，失败即部署失败
  home.activation.decryptSshIdRsa = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
      -o "${config.home.homeDirectory}/.ssh/id_rsa" ${../../../secrets/hosts/mba-m5/ssh_id_rsa.age}
  '';
}
