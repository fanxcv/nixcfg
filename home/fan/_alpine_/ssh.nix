# ssh 配置（Alpine 服务器专属）
# 客户端：对应脚本 post_config_alpine() 的 /etc/ssh/ssh_config 部分（HashKnownHosts + ssh-rsa）
# 服务端：PubkeyAcceptedKeyTypes 白名单（对应脚本追加到 sshd_config 的那行，原样迁移）
#   注意其中 ssh-rsa 是 SHA-1 签名（旧客户端兼容），属安全降级，介意可删掉该项
#   依赖 ../_common_/ssh.nix 的 sshConfig 先执行（entryAfter），保证公钥先就位

{ pkgs, lib, ... }:
{
  home.file.".ssh/config".text = ''
    Host *
      HashKnownHosts yes
      PubkeyAcceptedKeyTypes=+ssh-rsa
  '';

  home.activation.sshdKeyTypes = lib.hm.dag.entryAfter [ "sshConfig" ] ''
    set_sshd_keytypes() {
      if [ ! -f /etc/ssh/sshd_config ]; then
        return 0
      fi
      # 已配置过则跳过（幂等，不重复追加/重启）
      if grep -q '^Pubkeyacceptedkeytypes' /etc/ssh/sshd_config; then
        return 0
      fi

      SUDO=""
      [ "$(id -u)" = 0 ] || SUDO="sudo"

       cp /etc/ssh/sshd_config /etc/ssh/sshd_config.hm-bak || return 0
      echo 'Pubkeyacceptedkeytypes ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa' \
        |  tee -a /etc/ssh/sshd_config > /dev/null

      if  /usr/sbin/sshd -t 2>/dev/null; then
        echo "===> sshd PubkeyAcceptedKeyTypes 已更新，重启 sshd"
         rc-service sshd restart 2>/dev/null \
          ||  systemctl restart ssh 2>/dev/null \
          ||  systemctl restart sshd 2>/dev/null \
          || echo "警告: sshd 重启失败，请手动重启"
      else
         mv -f /etc/ssh/sshd_config.hm-bak /etc/ssh/sshd_config
        echo "警告: sshd -t 验证失败，PubkeyAcceptedKeyTypes 已回滚"
      fi
       rm -f /etc/ssh/sshd_config.hm-bak
    }
    set_sshd_keytypes
  '';
}
