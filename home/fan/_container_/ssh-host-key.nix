# ide 容器 SSH host key 固定（agenix 加密入库，激活期解密到 /etc/ssh-host-keys/）
# 无 bind mount（compose 已移除 ./ssh-keys 挂载）：key 由本激活脚本写容器内目录并同步 /etc/ssh/；
# 容器重建后 entrypoint 会先生成临时 key，激活时总是覆盖（age -d 本地解密毫秒级）+ reload sshd
# entrypoint.sh（docker/ide/ubuntu/entrypoint.sh）检测到 key 存在则跳过生成，直接 cp 到 /etc/ssh/
# 密钥文件：secrets/hosts/<hostName>/ssh_host_ed25519_key(.pub).age（与 nix-pve 同构，encrypt.sh 加密，keys.nix 的 ide 公钥）

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
    # 总是解密覆盖（容器重建后 entrypoint 生成的临时 key 会被替换为固定 key）
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$KEY_DIR/ssh_host_ed25519_key" ${../../..}/secrets/hosts/${hostName}/ssh_host_ed25519_key.age
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$KEY_DIR/ssh_host_ed25519_key.pub" ${../../..}/secrets/hosts/${hostName}/ssh_host_ed25519_key.pub.age
    chmod 600 "$KEY_DIR/ssh_host_ed25519_key"
    chmod 644 "$KEY_DIR/ssh_host_ed25519_key.pub"
    # 同步到 sshd 实际使用路径并重载（重建后 entrypoint 的临时 key 尚未被替换）
    cp -f "$KEY_DIR/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
    cp -f "$KEY_DIR/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
    chmod 600 /etc/ssh/ssh_host_ed25519_key
    chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
    /usr/bin/systemctl reload ssh 2>/dev/null || /usr/bin/systemctl reload sshd 2>/dev/null || true
    echo "[ssh-host-key] ${hostName} host key 就位（固定指纹，重建/重装后不变）"
  '';
}
