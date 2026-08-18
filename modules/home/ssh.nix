# ssh 配置模块（从 _common_/ssh.nix + 机器层 ssh.nix/ssh-config.nix 收敛，加 softwares.ssh.enable 门控）
# 三块逻辑：
#   1. 授权公钥拉取 + sshd 禁用密码（对应 alpine-init.sh 的 ssh_config()，所有平台；mac 的 uname 守卫自动跳过系统加固）
#   2. darwin 用户身份密钥解密（~/.ssh/id_rsa，age 路径按 hostName 参数化 → secrets/hosts/<host>/ssh_id_rsa.age）
#   3. ssh config 解密（~/.ssh/config ← secrets/ssh-config.age；mba-m5/mbp-m1/nix-pve 需要；nix-pve 额外删 orbstack include 行）
# 启用：common 默认 enable=true；某台不装 → 机器层 softwares.ssh.enable = lib.mkForce false

{ config, lib, pkgs, tools, hostName, ... }:   # GitHub 加速/例外由 tools/config.nix 控制（tools.githubUrl）
{
  options.softwares.ssh.enable = lib.mkEnableOption "ssh 配置（公钥拉取 + sshd 加固 + 身份/ssh-config 解密）";

  config = lib.mkIf config.softwares.ssh.enable {
    # ---------- 1) 授权公钥 + sshd 加固（common，mac 跳过） ----------
    home.activation.sshConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      configure_ssh() {
        # macOS 跳过（无 sshd_config 管理需求）
        [ "$(uname -s)" = "Linux" ] || return 0
        # 系统 PATH 由 _common_/path.nix 统一补（activatePathFix，writeBoundary 前置）

        # 1) 拉取授权公钥（对应脚本 ssh_config() 的 curl 部分）
        #    注意：file.fan-x.fun 的 mac.pub 曾返回 OneDrive HTML（非公钥），不再作为源；
        #    改为 github 的 keys + 内置本机 id_rsa（声明式，不依赖外部文件服务）
        #    URL 用 tools.githubUrl：github.com/<user>.keys 端点 ghfast 不支持，已在集中配置 withoutProxy 例外，自动直连
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        keys_tmp="$HOME/.ssh/authorized_keys.tmp"
        : > "$keys_tmp"
        if ${pkgs.curl}/bin/curl -sfL "${tools.githubUrl "https://github.com/fanxcv.keys"}" -o "$keys_tmp" \
          && [ -s "$keys_tmp" ]; then
          # 追加 mac 身份公钥（各台自己的 id_rsa：mini-m4 / mba-m5 / mbp-m1，即原 mac-pub.pub；
          # github 集合可能不含最新 key，防激活覆盖锁死）
          # 注意 mba-m5 与 mbp-m1 共用同一套 id_rsa（secrets/hosts/<host>/ssh_id_rsa.pub 同内容，
          #   authorized_keys 重复行无害，ssh 按 key 去重）
          printf '%s\n' '${builtins.readFile ../../secrets/hosts/mini-m4/ssh_id_rsa.pub}' >> "$keys_tmp"
          printf '%s\n' '${builtins.readFile ../../secrets/hosts/mba-m5/ssh_id_rsa.pub}' >> "$keys_tmp"
          printf '%s\n' '${builtins.readFile ../../secrets/hosts/mbp-m1/ssh_id_rsa.pub}' >> "$keys_tmp"
          mv -f "$keys_tmp" "$HOME/.ssh/authorized_keys"
          chmod 600 "$HOME/.ssh/authorized_keys"
        else
          rm -f "$keys_tmp"
          echo "警告: 公钥拉取失败，保留现有 ~/.ssh/authorized_keys"
        fi

        # 2) sshd 禁用密码认证（公钥未就位则跳过，防止禁密码后无法登录）
        if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
          echo "警告: authorized_keys 为空，跳过 sshd 加固"
          return 0
        fi
        [ -f /etc/ssh/sshd_config ] || return 0

        SUDO=""
        [ "$(id -u)" = 0 ] || SUDO="sudo"
        sshd_config=/etc/ssh/sshd_config

        # 备份 + 注释旧行 + 幂等追加
         cp "$sshd_config" "$sshd_config.hm-bak" || return 0
         ${pkgs.gnused}/bin/sed -i 's/^\(\s*\(PasswordAuthentication\|ChallengeResponseAuthentication\) .\+\)/# \1/g' "$sshd_config"
        grep -q '^PasswordAuthentication no' "$sshd_config" \
          || echo 'PasswordAuthentication no' |  tee -a "$sshd_config" > /dev/null
        grep -q '^ChallengeResponseAuthentication no' "$sshd_config" \
          || echo 'ChallengeResponseAuthentication no' |  tee -a "$sshd_config" > /dev/null

        # 验证：失败先剔除 ChallengeResponse（OpenSSH 9.8+ 已移除该指令），仍失败则整体回滚
        if !  /usr/sbin/sshd -t 2>/dev/null; then
           ${pkgs.gnused}/bin/sed -i '/^ChallengeResponseAuthentication no/d' "$sshd_config"
          if !  /usr/sbin/sshd -t 2>/dev/null; then
             mv -f "$sshd_config.hm-bak" "$sshd_config"
            echo "警告: sshd -t 验证失败，已回滚配置"
            return 0
          fi
          echo "提示: 当前 OpenSSH 不支持 ChallengeResponseAuthentication（9.8+ 已移除），已跳过该项"
        fi

        # 配置有变才重启（兼容 Alpine rc-service / Ubuntu systemctl）
        before=$(${pkgs.coreutils}/bin/md5sum "$sshd_config.hm-bak" | cut -d' ' -f1)
        after=$(${pkgs.coreutils}/bin/md5sum "$sshd_config" | cut -d' ' -f1)
         rm -f "$sshd_config.hm-bak"
        if [ "$before" != "$after" ]; then
          echo "===> sshd_config 已变更，重启 sshd"
          # failed 状态会让 restart 直接报错（如上次重启中断），先清状态
          systemctl reset-failed ssh 2>/dev/null || true
          if ! (rc-service sshd restart 2>/dev/null \
            || systemctl restart ssh 2>/dev/null \
            || systemctl restart sshd 2>/dev/null); then
            echo "警告: sshd 重启失败，请手动重启；诊断信息（status/journal 尾部）："
            # || true：activate 是 set -eu + pipefail，systemctl status 对 failed/不存在 unit 返回非零会中断激活
            systemctl status ssh --no-pager 2>/dev/null | tail -n 8 | sed 's/^/  /' || true
            journalctl -u ssh -n 10 --no-pager 2>/dev/null | tail -n 10 | sed 's/^/  /' || true
          fi
        fi
      }
      configure_ssh
    '';

    # ---------- 2) darwin 用户身份密钥解密（hostName 参数化） ----------
    home.activation.decryptSshIdRsa = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        umask 077
        ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
          -o "${config.home.homeDirectory}/.ssh/id_rsa" ${../../secrets/hosts/${hostName}/ssh_id_rsa.age}
      ''
    );

    # ---------- 3) ssh config 解密（mba-m5 / mbp-m1 / nix-pve；nix-pve 额外删 orbstack include） ----------
    home.activation.decryptSshConfig = lib.mkIf (builtins.elem hostName [ "mba-m5" "mbp-m1" "nix-pve" ]) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        umask 077
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
          -o "${config.home.homeDirectory}/.ssh/config" ${../../secrets/ssh-config.age}
        chmod 600 "${config.home.homeDirectory}/.ssh/config"
        ${lib.optionalString (hostName == "nix-pve") ''
          ${pkgs.gnused}/bin/sed -i '/^Include ~\/\.orbstack\/ssh\/config$/d' "${config.home.homeDirectory}/.ssh/config"
        ''}
      ''
    );
  };
}
