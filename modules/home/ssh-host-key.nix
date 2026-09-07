# SSH host key 固定模块（age 加密入库，激活期解密覆盖 sshd 私钥）。
# 服务器直接写 /etc/ssh/；容器先写 /etc/ssh-host-keys/，再同步 /etc/ssh/ 并 reload sshd。
# 密钥文件：secrets/hosts/<hostName>/ssh-host-key.age（加密）+ .pub（明文）。

{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  cfg = config.softwares.sshHostKey;
in
{
  options.softwares.sshHostKey = {
    enable = lib.mkEnableOption "SSH host key 固定（age 解密覆盖）";
    syncToSshDir = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "容器模式：解密到 /etc/ssh-host-keys/ 并同步 /etc/ssh/ + reload sshd";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.setupSshHostKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      KEY_DIR=${if cfg.syncToSshDir then "/etc/ssh-host-keys" else "/etc/ssh"}
      AGE_BIN="${pkgs.age}/bin/age"
      AGE_KEY="$HOME/.secrets/age-keys.txt"
      if [ ! -f "$AGE_KEY" ]; then
        echo "警告: 未找到 ''${AGE_KEY}，ssh host key 跳过${lib.optionalString cfg.syncToSshDir "（entrypoint 将首次生成）"}"
        exit 0
      fi
      ${lib.optionalString cfg.syncToSshDir ''
        mkdir -p "$KEY_DIR"
      ''}
      umask 077
      ${lib.optionalString cfg.syncToSshDir ''
        # 总是解密覆盖（容器重建后 entrypoint 生成的临时 key 会被替换为固定 key）
      ''}
      "$AGE_BIN" -d -i "$AGE_KEY" -o "$KEY_DIR/ssh_host_ed25519_key" ${../../secrets/hosts/${hostName}/ssh-host-key.age}
      ${lib.optionalString cfg.syncToSshDir ''
        # 公钥明文入库，直接拷贝（不加密）
      ''}
      cp -f ${../../secrets/hosts/${hostName}/ssh-host-key.pub} "$KEY_DIR/ssh_host_ed25519_key.pub"
      chmod 600 "$KEY_DIR/ssh_host_ed25519_key"
      chmod 644 "$KEY_DIR/ssh_host_ed25519_key.pub"
      ${lib.optionalString cfg.syncToSshDir ''
        # 同步到 sshd 实际使用路径并重载（重建后 entrypoint 的临时 key 尚未被替换）
        cp -f "$KEY_DIR/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
        cp -f "$KEY_DIR/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub
        chmod 600 /etc/ssh/ssh_host_ed25519_key
        chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
        /usr/bin/systemctl reload ssh 2>/dev/null || /usr/bin/systemctl reload sshd 2>/dev/null || true
      ''}
      echo "[ssh-host-key] ${hostName} host key 就位（固定指纹，${lib.optionalString cfg.syncToSshDir "重建/"}重装后不变）"
    '';
  };
}
