# ide 容器 SSH host key 固定（agenix 加密入库，激活期解密到 bind mount 目录）
# 目标 /etc/ssh-host-keys/ 由 compose bind mount 到宿主机 docker/ide/ssh-keys/：
#   容器重建后 key 不变（宿主机持久化）；服务器重装后 nix run .#<机器> 即恢复
# entrypoint.sh（docker/ide/ubuntu/entrypoint.sh）检测到 key 存在则跳过生成，直接 cp 到 /etc/ssh/
# 密钥文件：secrets/ssh-host-key.<hostName>(.pub).age（encrypt.sh 加密，keys.nix 的 ide 公钥）

{ lib, hostName, pkgs, ... }:
{
  home.activation.setupSshHostKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KEY_DIR=/etc/ssh-host-keys
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    if [ ! -f "$AGE_KEY" ]; then
      echo "警告: 未找到 ''${AGE_KEY}，ssh host key 跳过（entrypoint 将首次生成）"
      exit 0
    fi
    mkdir -p "$KEY_DIR"
    umask 077
    [ -f "$KEY_DIR/ssh_host_ed25519_key" ] \
      || "$AGE_BIN" -d -i "$AGE_KEY" -o "$KEY_DIR/ssh_host_ed25519_key" ${../../..}/secrets/ssh-host-key-${hostName}.age
    [ -f "$KEY_DIR/ssh_host_ed25519_key.pub" ] \
      || "$AGE_BIN" -d -i "$AGE_KEY" -o "$KEY_DIR/ssh_host_ed25519_key.pub" ${../../..}/secrets/ssh-host-key-${hostName}.pub.age
    chmod 600 "$KEY_DIR/ssh_host_ed25519_key"
    chmod 644 "$KEY_DIR/ssh_host_ed25519_key.pub"
    echo "[ssh-host-key] ${hostName} host key 就位（/etc/ssh-host-keys/，重建/重装后不变）"
  '';
}
