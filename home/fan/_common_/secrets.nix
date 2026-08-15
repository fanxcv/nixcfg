# AI 密钥等敏感环境变量注入（三平台通用）
# 密钥文件统一约定 $HOME/.secrets/ai.env，只存三个源 key（不进 nix 配置、不提交 git）：
#   export AI_FAN_CLAUDE=...   # claude key（claude code / pi 的 PIPI_CLAUDE_KEY）
#   export AI_FAN_CODEX=...    # codex key（pi 的 IPI_CODEX_KEY）
#   export AI_FAN_CHAT=...     # chat key（codex CLI 直接读 / pi 的 PIPI_CHAT_KEY）
# 各工具的变量映射在下方 initContent 统一派生，AI 工具无需感知源变量名
#   容器（root）  → /root/.secrets/ai.env，compose 挂载自宿主机，容器重建不丢
#   NixOS 真机    → /home/fan/.secrets/ai.env，本机文件（chmod 600，手动创建）
#   mac（fan）    → /Users/fan/.secrets/ai.env，本机文件（chmod 600，手动创建）
# 三平台共用同一行 $HOME 相对路径，无需任何分支；文件缺失时静默跳过

# === secrets 架构（统一规则，见 AGENTS.md）===============================
# fan 域 secrets 全部由 home.activation 解密（age -d 直接解，唯一机制）：
#   源：secrets/*.age（encrypt.sh 从 secrets/source/ 加密生成，git 可公开）
#   私钥：$HOME/.secrets/age-keys.txt（与 ai.env 同目录同挂载，容器重建不丢）
#   解密：本文件（ai.env/git-credentials）+ 各模块自带（tailscale/ssh/keystore/skemate），
#   模式统一、无 if 无兜底——私钥缺失或 .age 损坏即部署失败（暴露问题）
# 系统域 secrets（NixOS host keys、nix-pve comin 等）仍走 agenix 系统层（hosts/ 下声明）。
# HM 层不再 import agenix homeManagerModules（无 age.secrets 声明）。

{ pkgs, lib, ... }:
{
  programs.zsh.initContent = ''
    [ -f "$HOME/.secrets/ai.env" ] && source "$HOME/.secrets/ai.env"
    # AI key 映射：ai.env 的 AI_FAN_* → 各工具环境变量（未定义为无害空值）
    export ANTHROPIC_AUTH_TOKEN="$AI_FAN_CLAUDE"   # claude code（cc_claude 内也有独立派生）
    export PIPI_CLAUDE_KEY="$AI_FAN_CLAUDE"        # pi
    export IPI_CODEX_KEY="$AI_FAN_CODEX"           # pi
    export PIPI_CHAT_KEY="$AI_FAN_CHAT"            # pi
  '';

  # 统一解密（ai.env + git-credentials，全平台）；失败即中断部署
  home.activation.decryptUserSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    AGE_BIN="${pkgs.age}/bin/age"
    AGE_KEY="$HOME/.secrets/age-keys.txt"
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$HOME/.secrets/ai.env" ${../../..}/secrets/ai.env.age
    "$AGE_BIN" -d -i "$AGE_KEY" -o "$HOME/.git-credentials" ${../../..}/secrets/git-credentials.age
    chmod 600 "$HOME/.git-credentials"
  '';
}
