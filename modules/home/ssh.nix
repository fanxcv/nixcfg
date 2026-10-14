# ssh 配置模块（从 _common_/ssh.nix + 机器层 ssh.nix/ssh-config.nix 收敛，加 softwares.ssh.enable 门控）
# 三块逻辑：
#   1. 授权公钥拉取 + sshd 禁用密码（对应 alpine-init.sh 的 ssh_config()；加固仅对容器/云服务器生效，
#      NixOS 与 macOS 走各自 nix 层声明，PVE 不在本次范围）
#   2. darwin 用户身份密钥解密（~/.ssh/id_rsa，age 路径按 hostName 参数化 → secrets/hosts/<host>/ssh-user-key.age）
#   3. ssh config 解密（~/.ssh/config ← secrets/ssh-config.age；mba-m5/mbp-m1/nix-pve 需要；nix-pve 额外删 orbstack include 行）
# 启用：本模块默认 enable=true；某台不装 → 机器层 softwares.ssh.enable = lib.mkForce false

{
  config,
  lib,
  pkgs,
  tools,
  hostName,
  platform,
  ...
}: # GitHub 加速/例外由 tools/config.nix 控制（tools.githubUrl）
{
  options.softwares.ssh.enable = lib.mkEnableOption "ssh 配置（公钥拉取 + sshd 加固 + 身份/ssh-config 解密）" // {
    default = true;
  };

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

              # 1.5) PVE 集群节点分支：~/.ssh/authorized_keys 是 /etc/pve/priv/authorized_keys 的软链（pmxcfs 集群分发），
              #      mv 覆盖会毁集群互信（web shell 跨节点 Permission denied）——改为合并进集群共享文件（幂等追加），并恢复软链
              if [ -f /etc/pve/priv/authorized_keys ]; then
                if [ ! -L "$HOME/.ssh/authorized_keys" ]; then
                  rm -f "$HOME/.ssh/authorized_keys"
                  ln -s /etc/pve/priv/authorized_keys "$HOME/.ssh/authorized_keys"
                  echo "PVE: authorized_keys 已恢复集群软链（pmxcfs）"
                fi
                pve_keys=/etc/pve/priv/authorized_keys
                add_key() {
                  [ -n "$1" ] || return 0
                  grep -qF "$1" "$pve_keys" 2>/dev/null || { echo "$1" >> "$pve_keys"; echo "PVE: 公钥已并入集群信任（$(echo "$1" | cut -c1-40)…）"; }
                }
                ${pkgs.curl}/bin/curl -sfL --max-time 15 "${tools.githubUrl "https://github.com/fanxcv.keys"}" 2>/dev/null | while read -r line; do add_key "$line"; done || true  # || true：pipefail 下 curl 超时/网络不通不中断 activate（公钥拉取失败容忍）
                add_key "$(cat ${toString ../../secrets/hosts/mini-m4/ssh-user-key.pub} 2>/dev/null)"
                add_key "$(cat ${toString ../../secrets/hosts/mba-m5/ssh-user-key.pub} 2>/dev/null)"
                add_key "$(cat ${toString ../../secrets/hosts/mbp-m1/ssh-user-key.pub} 2>/dev/null)"
                # 合并后转普通分支的 sshd 加固（PasswordAuthentication no 等）
              else
                keys_tmp="$HOME/.ssh/authorized_keys.tmp"
                : > "$keys_tmp"
                if ${pkgs.curl}/bin/curl -sfL --max-time 15 "${tools.githubUrl "https://github.com/fanxcv.keys"}" -o "$keys_tmp" \
                  && [ -s "$keys_tmp" ]; then
                  # 追加身份公钥集合（tools/sshUserKeys.nix：mini-m4 / mba-m5 / mbp-m1 / nix-lenovo；
                  # github 集合可能不含最新 key，防激活覆盖锁死；重复行无害，ssh 按 key 去重）
                  ${lib.concatMapStrings (
                    k: "printf '%s\\n' '${k}' >> \"$keys_tmp\"\n"
                  ) tools.sshUserKeys.pubKeys}
                  mv -f "$keys_tmp" "$HOME/.ssh/authorized_keys"
                  chmod 600 "$HOME/.ssh/authorized_keys"
                else
                  rm -f "$keys_tmp"
                  echo "警告: 公钥拉取失败，保留现有 ~/.ssh/authorized_keys"
                fi
              fi

              # 2) sshd 禁用密码认证（公钥未就位则跳过，防止禁密码后无法登录）
              #    NixOS：/etc/ssh/sshd_config 是只读 store 链接，开关在 hosts/_nixos_/services/openssh.nix
              #    macOS：sshd 配置由 hosts/_darwin_/base/ssh.nix 声明
              #    PVE：本次变更范围排除，保持既有行为
              if [ "${platform}" = "nixos" ] || [ "${platform}" = "darwin" ]; then
                echo "NixOS/macOS：sshd 加固走 nix 层声明，跳过运行时改写"
                return 0
              fi
              if [ "${platform}" = "pve" ]; then
                echo "PVE：跳过 sshd 加固（变更范围排除 PVE）"
                return 0
              fi
              if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
                echo "警告: authorized_keys 为空，跳过 sshd 加固"
                return 0
              fi
              [ -d /etc/ssh ] || return 0

              # 写 sshd_config.d 优先文件：Ubuntu/Debian 主 sshd_config 顶部 Include 该目录，
              # 而 cloud-init 的 50-cloud-init.conf 会把 PasswordAuthentication 设回 yes；
              # sshd 取「首次出现的值」，故 00- 前缀排到最前才能压过 cloud-init 与主文件。
              # KbdInteractiveAuthentication 同关：Ubuntu 默认 UsePAM yes，只关前者密码仍可经 PAM 登入。
              dropin_dir=/etc/ssh/sshd_config.d
              dropin=$dropin_dir/00-nix-hardening.conf
              before=""
              if [ -f "$dropin" ]; then
                before=$(${pkgs.coreutils}/bin/md5sum "$dropin" | cut -d' ' -f1)
              fi
              mkdir -p "$dropin_dir"
              cat > "$dropin" <<'SSHD_HARDENING_EOF'
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      SSHD_HARDENING_EOF
              chmod 644 "$dropin"

              # 清理旧版运行时改写留在主文件的追加行（现走 dropin；残留的
              # ChallengeResponseAuthentication 在 OpenSSH 9.8+ 已移除，会让 sshd -t 失败）
              if [ -f /etc/ssh/sshd_config ]; then
                ${pkgs.gnused}/bin/sed -i '/^\(PasswordAuthentication\|ChallengeResponseAuthentication\) no$/d' /etc/ssh/sshd_config
              fi

              if ! /usr/sbin/sshd -t 2>/dev/null; then
                rm -f "$dropin"
                echo "警告: sshd -t 验证失败，已移除 $dropin"
                return 0
              fi

              after=$(${pkgs.coreutils}/bin/md5sum "$dropin" | cut -d' ' -f1)
              if [ -n "$before" ] && [ "$before" = "$after" ]; then
                echo "sshd 加固已就位，无变化"
                return 0
              fi

              echo "===> sshd 加固已变更（$dropin），重启 sshd"
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
            }
            configure_ssh
    '';

    # ---------- 2) 身份私钥解密（持有私钥的机器） ----------
    # 门控用 platform/hostName 而非 hostPlatform.isDarwin：跨架构构建（如 darwin 宿主上构建容器配置）会误判
    # mac 沿用既有 id_rsa；nix-lenovo 为 ed25519 → id_ed25519
    # 私钥必装；公钥仅当仓库里存在时一并落位（缺失则跳过，不报错）——
    #   ssh-copy-id 默认身份查找是 `ls -dt ~/.ssh/id*.pub`，只有私钥会让它报「无可用身份」而失败
    home.activation.decryptSshIdentity =
      let
        pubKey = ../../secrets/hosts/${hostName}/ssh-user-key.pub;
      in
      lib.mkIf (platform == "darwin" || hostName == "nix-lenovo") (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          umask 077
          mkdir -p "$HOME/.ssh"
          chmod 700 "$HOME/.ssh"
          identity="$HOME/.ssh/${if hostName == "nix-lenovo" then "id_ed25519" else "id_rsa"}"
          ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
            -o "$identity" ${../../secrets/hosts/${hostName}/ssh-user-key.age}
          chmod 600 "$identity"
          ${lib.optionalString (builtins.pathExists pubKey) ''
            cp -f ${pubKey} "$identity.pub"
            chmod 644 "$identity.pub"
          ''}
        ''
      );

    # ---------- 3) ssh config 解密（mba-m5 / mbp-m1 / nix-pve；nix-pve 额外删 orbstack include） ----------
    home.activation.decryptSshConfig =
      lib.mkIf
        (builtins.elem hostName [
          "mba-m5"
          "mbp-m1"
          "nix-pve"
        ])
        (
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
