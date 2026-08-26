# codex 配置模块（从 _common_/codex.nix 迁入，加 softwares.codex.enable 门控）
# 默认模板策略：存在跳过，不存在生成
# 通用段：provider（fan 代理）/ model / 多 agent / context7 MCP / ficc-coding-standards 插件
# 密钥：codex 直接读环境变量 AI_FAN_CODEX（temp_env_key），值由 ~/.secrets/ai.env 提供
# 写实体文件而非 home.file symlink（关键）：
#   codex 运行时要持久化项目信任/状态回 config.toml，symlink 指向 nix store 只读文件会报
#   "failed to persist config.toml"（code -32603）；tsln 仓库同源思路——实体可写文件
# 存在跳过：config.toml 已存在（用户自管）不覆盖；不存在才写默认模板。
#   机器特定配置（blender/pencil MCP、项目信任等）由用户直接维护在 config.toml，nix 不参与；
#   如需回归 nix 默认，删除文件后部署一次即可
#
# 启用（各层引用）：
#   common/_common_/default.nix 显式 enable=true（所有机器默认装）
#   某台不装 → 机器层 softwares.codex.enable = lib.mkForce false

{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.softwares.codex.enable = lib.mkEnableOption "codex（CLI 编码 agent，config 默认模板由 nix 声明）";

  config = lib.mkIf config.softwares.codex.enable {
    # codex 包（Rust 编译，unstable 通道——周级 flake update 跟随，与 vscode 同机制）
    home.packages = [ pkgs.repos.unstable.codex ];

    # 默认模板写实体文件（install 先 unlink 旧 symlink，天然幂等）
    home.activation.setupCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "$HOME/.codex/config.toml" ]; then
        echo "codex: config.toml 已存在，跳过（不覆盖用户配置）"
      else
        mkdir -p "$HOME/.codex"
        ${pkgs.coreutils}/bin/install -m 644 ${./codex/config.toml} "$HOME/.codex/config.toml"
        echo "codex: config.toml 不存在，已生成默认模板"
      fi
    '';
  };
}
