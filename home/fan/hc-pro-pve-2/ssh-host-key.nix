# hc-pro-pve-2 SSH host key 固定（age 加密入库，激活期解密覆盖 /etc/ssh/）
# 提取自服务器现有 ed25519 key（known_hosts 不变）；重装/sshd 重装后 key 不变
# 密钥文件：secrets/hosts/hc-pro-pve-2/ssh-host-key.age（加密）+ .pub（明文，直接拷贝）
# 不重启 sshd：key 内容与现有一致，sshd 下次重启自然生效（restart 会杀 ssh 会话）

{
  lib,
  pkgs,
  ...
}:
{
  home.activation.setupSshHostKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    if [ ! -f "$AGE_KEY" ]; then
      echo "警告: 未找到 ''${AGE_KEY}，ssh host key 跳过"
      exit 0
    fi
    umask 077
    "$AGE_BIN" -d -i "$AGE_KEY" -o /etc/ssh/ssh_host_ed25519_key ${../../..}/secrets/hosts/hc-pro-pve-2/ssh-host-key.age
    cp -f ${../../..}/secrets/hosts/hc-pro-pve-2/ssh-host-key.pub /etc/ssh/ssh_host_ed25519_key.pub
    chmod 600 /etc/ssh/ssh_host_ed25519_key
    chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
    echo "[ssh-host-key] hc-pro-pve-2 host key 就位（固定指纹，重装后不变）"
  '';
}
