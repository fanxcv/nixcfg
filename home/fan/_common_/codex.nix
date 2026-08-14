# codex 配置（nix 只管理通用段）
# 通用段：provider（fan 代理）/ model / 多 agent / context7 MCP / ficc-coding-standards 插件
# 密钥：codex 直接读环境变量 AI_FAN_CHAT（temp_env_key），值由 ~/.secrets/ai.env 提供
# 机器特定配置（blender/pencil MCP、项目信任、hooks 指纹）**不让 nix 管理**：
#   手动维护在 ~/.codex/config.machine.toml（不提交 git），
#   activation 每次 switch 自动合并进 config.toml，手动段永不被 nix 覆盖
# marketplace 状态字段（last_updated/last_revision）由 codex 自管，nix 覆盖后 codex 会重新同步

{ pkgs, lib, ... }:
{
  # codex 包（Rust 编译，unstable 通道——周级 flake update 跟随，与 vscode 同机制）
  home.packages = [ pkgs.repos.unstable.codex ];

  home.file.".codex/config.toml".text = ''
    model_provider = "fan"
    model = "gpt-5.6-sol"
    model_reasoning_effort = "xhigh"
    service_tier = "default"
    approvals_reviewer = "user"

    [model_providers.fan]
    name = "fan"
    base_url = "https://ai.qksxin.com/v1"
    wire_api = "responses"
    temp_env_key = "AI_FAN_CODEX"
    requires_openai_auth = true
    model = "gpt-5.4"

    [features]
    multi_agent = true

    [features.multi_agent_v2]
    enabled = true
    hide_spawn_agent_metadata = false
    tool_namespace = "agents"
    max_concurrent_threads_per_session = 8
    min_wait_timeout_ms = 10000
    default_wait_timeout_ms = 30000
    max_wait_timeout_ms = 120000

    [agents]
    max_threads = 8

    [mcp_servers.context7]
    command = "npx"
    args = [ "-y", "@upstash/context7-mcp@latest" ]
    startup_timeout_sec = 30

    [plugins."ficc-coding-standards@ficc-coding-standards"]
    enabled = true

    [marketplaces.ficc-coding-standards]
    source_type = "git"
    source = "https://hc-git.qksxin.com/hc/ai-plugins.git"
  '';

  # 合并本机手动段：config.machine.toml 存在则追加（home.file 每次全量写通用段后执行，天然幂等）
  home.activation.mergeCodexMachine = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/.codex/config.machine.toml" ]; then
      cat "$HOME/.codex/config.machine.toml" >> "$HOME/.codex/config.toml"
      echo "===> 已合并 ~/.codex/config.machine.toml（机器特定段）"
    fi
  '';
}
