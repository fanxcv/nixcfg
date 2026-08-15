# claude-code + ccline（包与配置，全平台）
# 包：
#   claude-code → nixpkgs 原生二进制（官方 CDN 国内不可达，src 由 overlays/claude-code.nix 改 npmmirror）
#   ccline      → claude 的 statusline 配件（Rust 二进制，npm 平台包即裸二进制，fetchurl 分发）
# 配置管理：settings.json 默认模板（存在跳过，实体文件）+ cc_claude 启动 wrapper
#   settings.json：文件已存在时不覆盖（用户自管）；不存在才生成默认模板
#   代理地址在 cc_claude，token 一律走 ~/.secrets/ai.env（secrets.nix），不进 nix 配置
#   ficc-coding-standards 等插件市场声明在 settings.json，插件内容由 claude 自行拉取
#   statusLine 用 "ccline" 命令名（不嵌 store 路径）：由本文件 home.packages 装入
#   ~/.nix-profile/bin，claude 从 shell 启动时 PATH 可解析（从 GUI 启动时需手动加 PATH）

{ pkgs, lib, useChinaMirror ? true, ... }:
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
    # 关 installCheck：claude --version 在 nixbld（无 HOME）环境会死循环（99% CPU），
    # 构建本身没问题（npmmirror 裸二进制，见 overlays/claude-code.nix）
    # unstable 通道（周级 flake update 跟随，与 vscode 同机制；claudeOverlay 已应用到 unstable 实例）
    (pkgs.repos.unstable.claude-code.overrideAttrs { doInstallCheck = false; })
    ccline
  ];

  # ---- claude code 全局配置默认模板（~/.claude/settings.json）----
  # 存在跳过：文件已存在（用户自管）不覆盖；不存在才写默认模板（实体文件，可写回）
  # 本机用户已存在时 nix 不再干涉；如需回归 nix 默认，删除文件后部署一次即可
  home.activation.setupClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/.claude/settings.json" ]; then
      echo "claude: settings.json 已存在，跳过（不覆盖用户配置）"
    else
      mkdir -p "$HOME/.claude"
      ${pkgs.coreutils}/bin/install -m 644 ${./claude/settings.json} "$HOME/.claude/settings.json"
      echo "claude: settings.json 不存在，已生成默认模板"
    fi
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
