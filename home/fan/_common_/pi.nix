# pi agent 配置：从 git.fan-x.fun/fan/pi-config 拉取到 ~/.pi/agent/
# 仓库为自建 Gitea（非 GitHub，无需 gh-proxy），私有需要只读密钥：
#   token 从 $HOME/.secrets/ai.env 读取（PI_CONFIG_GIT_TOKEN=...），不进 nix 配置、不提交 git
#   clone 后 origin 移除 token，后续更新走 ~/.git-credentials（容器里挂载宿主机）
# 幂等：已有 .git 跳过 clone；每次 switch 静默 pull（--ff-only）

{ pkgs, lib, ... }:
{
  # pi-coding-agent 包（npm 打包 buildNpmPackage，自带 node）
  home.packages = [ pkgs.pi-coding-agent ];

  # 默认：装了 pi 的机器用 mise 安装 node@lts（pi 运行时依赖 node）
  # config.local.toml 优先级低于 config.toml——机器主配置可覆盖，如 mini-m4 用 node@24
  home.file.".config/mise/config.local.toml".text = ''
    [tools]
    node = "lts"
  '';
  # ---- pi 启动 wrapper（本机 ~/.pi/agent/bin/fpi 的 nix 化）----
  # fff 覆盖模式（PI_FFF_MODE=override），pi 由 nix 提供（原生二进制），不再依赖 mise node@22
  home.file.".local/bin/fpi" = {
    executable = true;
    text = ''
      #!/usr/bin/env zsh
      # 由 nix 管理（pi.nix）；原版见 ~/.pi/agent/bin/fpi（pi-config 仓库）

      export PI_FFF_MODE=override

      exec pi $@
    '';
  };

  home.activation.setupPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_pi() {
      PI_REPO="https://git.fan-x.fun/fan/pi-config.git"
      PI_DIR="$HOME/.pi/agent"

      # 只读密钥从密钥文件读取（缺失时走匿名 clone，私有仓库会失败并警告）
      PI_TOKEN=""
      if [ -f "$HOME/.secrets/ai.env" ]; then
        PI_TOKEN=$(grep -E '^(export )?PI_CONFIG_GIT_TOKEN=' "$HOME/.secrets/ai.env" 2>/dev/null | head -1 | sed 's/^export //' | cut -d= -f2-)
      fi

      # 非交互：凭据缺失/无效时 git 直接失败返回，避免激活卡在密码提示
      export GIT_TERMINAL_PROMPT=0

      if [ ! -e "$PI_DIR/.git" ]; then
        rm -rf "$PI_DIR"
        mkdir -p "$HOME/.pi"
        if [ -n "$PI_TOKEN" ]; then
          # Gitea Basic 认证：用户名 fan + 密码为 token；clone 后立即清掉
          ${pkgs.git}/bin/git clone --quiet "https://fan:''${PI_TOKEN}@git.fan-x.fun/fan/pi-config.git" "$PI_DIR" \
            || echo "警告: pi 配置 clone 失败（密钥无效或网络问题），可稍后手动拉取"
          # 清理 origin 里的 token，后续 pull 走 ~/.git-credentials
          ${pkgs.git}/bin/git -C "$PI_DIR" remote set-url origin "$PI_REPO" 2>/dev/null || true
        else
          ${pkgs.git}/bin/git clone --quiet "$PI_REPO" "$PI_DIR" \
            || echo "警告: pi 配置 clone 失败（未配置 PI_CONFIG_GIT_TOKEN，仓库可能私有）"
        fi
      fi

      # 每次 switch 静默更新（失败不影响激活）
      if [ -e "$PI_DIR/.git" ]; then
        ${pkgs.git}/bin/git -C "$PI_DIR" pull --ff-only --quiet 2>/dev/null || true
      fi
    }
    setup_pi
  '';
}
