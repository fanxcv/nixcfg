# macOS sshd 声明（nix-darwin）：关密码认证 + 授权四台机器的身份公钥。
#   extraConfig → /etc/ssh/sshd_config.d/100-nix-darwin.conf；macOS 主 sshd_config 顶部已
#   Include 该目录，且 macOS 默认 UsePAM yes，故 PasswordAuthentication 与
#   KbdInteractiveAuthentication 两者都要关，否则 PAM 密码仍可登。
#   authorizedKeys → /etc/ssh/nix_authorized_keys.d/<user>（nix-darwin 的 AuthorizedKeysCommand 读取）。
{ tools, ... }:
{
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
    '';
  };

  users.users.fan.openssh.authorizedKeys.keys = tools.sshUserKeys.pubKeys;
}
