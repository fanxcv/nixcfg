# SSH 客户端配置由 nix 管理（~/.ssh/config）
#   secrets/ssh-config.age 激活解密（同 git-credentials 机制，失败即部署失败）
#   与 mac 差异：本机无 OrbStack，解密后删除 Include ~/.orbstack/ssh/config 行
{ pkgs, lib, config, ... }:
{
  home.activation.decryptSshConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
      -o "${config.home.homeDirectory}/.ssh/config" ${../../../secrets/ssh-config.age}
    chmod 600 "${config.home.homeDirectory}/.ssh/config"
    ${pkgs.gnused}/bin/sed -i '/^Include ~\/\.orbstack\/ssh\/config$/d' "${config.home.homeDirectory}/.ssh/config"
  '';
}
