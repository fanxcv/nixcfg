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
#
# === agenix 升级（可选）=================================================
# 上面是"宿主机放明文 + 挂载进容器"；agenix 可让 key 加密入库（secrets/*.age，
# git 可公开），激活时自动解密到同一路径。启用步骤（secrets/README.md 有完整命令）：
#   1. 加密文件就位：secrets/ai.env.age、secrets/git-credentials.age（age -e -r <pubkey>）
#   2. 取消下方 imports / age.* 两处注释
#   3. 私钥就位：$HOME/.secrets/age-keys.txt（与 ai.env 同目录同挂载，容器重建不丢）
#   4. 容器内 nix run .#ide 重新激活验证
# 注意：age.secrets 在激活期解密，file 缺失或私钥不在会导致激活失败（不做静默跳过），
# 所以未启用前保持注释，避免影响现有容器。

{ pkgs, lib, inputs, config, ... }:
{
  programs.zsh.initContent = ''
    [ -f "$HOME/.secrets/ai.env" ] && source "$HOME/.secrets/ai.env"
    # AI key 映射：ai.env 的 AI_FAN_* → 各工具环境变量（未定义为无害空值）
    export ANTHROPIC_AUTH_TOKEN="$AI_FAN_CLAUDE"   # claude code（cc_claude 内也有独立派生）
    export PIPI_CLAUDE_KEY="$AI_FAN_CLAUDE"        # pi
    export IPI_CODEX_KEY="$AI_FAN_CODEX"           # pi
    export PIPI_CHAT_KEY="$AI_FAN_CHAT"            # pi
  '';

  # .git-credentials 由密钥文件生成（git credential.helper=store 的读取源）：
  #   凭据（每行 https://user:token@host）维护在 ~/.secrets/git-credentials（不进 git）
  #   cp -u：仅当 .secrets 版更新时覆盖——git 新写入的凭据（mtime 较新）保留不被重置
  home.activation.gitCredentials = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/.secrets/git-credentials" ]; then
      cp -u "$HOME/.secrets/git-credentials" "$HOME/.git-credentials"
      chmod 600 "$HOME/.git-credentials"
    fi
  '';

  # === agenix：加密 secrets 自动解密（启用时取消下方注释）=================
  # imports = [ inputs.agenix.homeManagerModules.default ];
  #
  # age.identityPaths = [ "${config.home.homeDirectory}/.secrets/age-keys.txt" ];
  # age.secrets.aiEnv = {
  #   file = ../../../secrets/ai.env.age;   # 相对本文件：仓库根/secrets/
  #   path = "${config.home.homeDirectory}/.secrets/ai.env";
  #   mode = "600";
  # };
  # age.secrets.gitCredentials = {
  #   file = ../../../secrets/git-credentials.age;
  #   path = "${config.home.homeDirectory}/.git-credentials";
  #   mode = "600";
  # };
}
