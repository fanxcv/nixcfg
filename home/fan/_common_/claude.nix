# claude-code + ccline（包与配置，全平台）
# 包：
#   claude-code → nixpkgs 原生二进制（官方 CDN 国内不可达，src 由 overlays/claude-code.nix 改 npmmirror）
#   ccline      → claude 的 statusline 配件（Rust 二进制，npm 平台包即裸二进制，fetchurl 分发）
# 配置声明式管理：settings.json（无密钥）+ cc_claude 启动 wrapper
#   代理地址在 cc_claude，token 一律走 ~/.secrets/ai.env（secrets.nix），不进 nix 配置
#   ficc-coding-standards 等插件市场声明在 settings.json，插件内容由 claude 自行拉取
#   statusLine 用 "ccline" 命令名（不嵌 store 路径）：由本文件 home.packages 装入
#   ~/.nix-profile/bin，claude 从 shell 启动时 PATH 可解析（从 GUI 启动时需手动加 PATH）

{ pkgs, useChinaMirror ? true, ... }:
let
  # 国内网络开关（flake.nix 传入）：npm registry 走 npmmirror（与 ai.nix/mise.nix 同一开关）
  npmRegistry = if useChinaMirror then "https://registry.npmmirror.com" else "https://registry.npmjs.org";

  # 平台标识：nix 的 isx86_64/isAarch64 对应官方分发后缀 x64/arm64
  os = if pkgs.stdenv.hostPlatform.isLinux then "linux"
    else if pkgs.stdenv.hostPlatform.isDarwin then "darwin"
    else throw "unsupported os: ${pkgs.stdenv.hostPlatform.system}";
  arch = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64"
    else if pkgs.stdenv.hostPlatform.isx86_64 then "x64"
    else throw "unsupported arch: ${pkgs.stdenv.hostPlatform.system}";
  platKey = "${os}-${arch}";

  # ---- ccline：npm 平台包即裸二进制（tarball 内 package/ccline）----
  ccline = pkgs.stdenv.mkDerivation {
    pname = "ccline";
    version = "1.1.2";
    src = pkgs.fetchurl {
      url = "${npmRegistry}/@cometix/ccline-${platKey}/-/ccline-${platKey}-1.1.2.tgz";
      sha256 = {
        "linux-arm64"   = "sha256-GPmcHoELYuDAB0FTfRD3PtJhQ39fRKJLFvrUL9zuZmg=";
        "linux-x64"     = "sha256-i9DpPMtbKJAnfdA7xLHlYbvSzQGmQ6RLq9wTirQzRYk=";
        "darwin-arm64"  = "sha256-FtAlfTYJFKBjAudLeN9xaz01bcYFjZ+BvTrxtcuHPMg=";
        "darwin-x64"    = "sha256-uri5CPZY0pRR3cExs7F1ObBiSWLDS/3AOSFBRIYA8f0=";
      }.${platKey};
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      tar xzf $src -C $out/bin --strip-components=1 package/ccline
      chmod +x $out/bin/ccline
      runHook postInstall
    '';
    meta = {
      description = "CCometixLine (ccline) - Claude Code StatusLine tool";
      homepage = "https://github.com/Haleclipse/CCometixLine";
      license = pkgs.lib.licenses.mit;
    };
  };
in
{
  home.packages = [
    pkgs.claude-code
    ccline
  ];

  # ---- claude code 全局配置（本机 ~/.claude/settings.json 的 nix 化，已剔除密钥）----
  home.file.".claude/settings.json".text = ''
    {
      "$schema": "https://json.schemastore.org/claude-code-settings.json",
      "env": {
        "DISABLE_TELEMETRY": "1",
        "DISABLE_ERROR_REPORTING": "1",
        "CLAUDE_CODE_ATTRIBUTION_HEADER": "0",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS0": "1",
        "MCP_TIMEOUT": "60000",
        "ENABLE_LSP_TOOL": "1"
      },
      "includeCoAuthoredBy": false,
      "permissions": {
        "allow": [
          "Bash", "BashOutput", "Edit", "Glob", "Grep", "KillShell", "NotebookEdit",
          "Read", "SlashCommand", "Task", "TodoWrite", "WebFetch", "WebSearch", "Write",
          "List", "LS", "Agent", "MultiEdit", "NotebookRead",
          "mcp__ide", "mcp__jetbrains", "mcp__pencil"
        ],
        "deny": []
      },
      "hooks": {},
      "statusLine": {
        "type": "command",
        "command": "ccline",
        "padding": 0
      },
      "enabledPlugins": {
        "context7@claude-plugins-official": true,
        "gopls-lsp@claude-plugins-official": true,
        "jdtls-lsp@claude-plugins-official": false,
        "kotlin-lsp@claude-plugins-official": false,
        "typescript-lsp@claude-plugins-official": true,
        "pyright-lsp@claude-plugins-official": false,
        "frontend-design@claude-plugins-official": true,
        "ficc-coding-standards@ficc-coding-standards": true,
        "beads@beads-marketplace": true,
        "skill-creator@claude-plugins-official": true
      },
      "extraKnownMarketplaces": {
        "ficc-coding-standards": {
          "source": {
            "source": "git",
            "url": "https://hc-git.qksxin.com/hc/ai-plugins.git"
          }
        },
        "beads-marketplace": {
          "source": {
            "source": "github",
            "repo": "gastownhall/beads"
          }
        }
      },
      "alwaysThinkingEnabled": true,
      "tui": "fullscreen",
      "teammateMode": "in-process",
      "permission_mode": "default"
    }
  '';

  # ---- claude 启动 wrapper（本机 ~/.claude/bin/cc_claude 的 nix 化）----
  # 代理地址 + token 注入（token 从 ai.env 读 ANTHROPIC_AUTH_TOKEN）+ root 下过滤危险参数
  # claude 由 nix 提供（原生二进制），不再依赖 mise node@22 / npm 版 claude
  home.file.".local/bin/cc_claude" = {
    executable = true;
    text = ''
      #!/usr/bin/env zsh
      # 由 nix 管理（claude.nix）；key 从密钥文件派生（AI_FAN_CLAUDE）

      [ -f "$HOME/.secrets/ai.env" ] && source "$HOME/.secrets/ai.env"

      export ANTHROPIC_BASE_URL=https://ai.qksxin.com
      export ANTHROPIC_AUTH_TOKEN="''${AI_FAN_CLAUDE:-}"

      exec claude $@
    '';
  };
}
