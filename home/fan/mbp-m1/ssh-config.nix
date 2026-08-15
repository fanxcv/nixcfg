# SSH 客户端配置由 nix 管理（~/.ssh/config）
#   secrets/ssh-config.age 激活解密（同 git-credentials 机制，失败即部署失败）
#   mac 直接用解密结果：OrbStack Include 行保留（本机有 OrbStack）
{ pkgs, lib, config, ... }:
{
  home.activation.decryptSshConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
      -o "${config.home.homeDirectory}/.ssh/config" ${../../../secrets/ssh-config.age}
    chmod 600 "${config.home.homeDirectory}/.ssh/config"
  '';
}
