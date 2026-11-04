# pi agent 配置模块（从 _common_/pi.nix 迁入，加 softwares.pi.enable 门控）
# 从 git.fan-x.fun/fan/pi-config 拉取到 ~/.pi/agent/
# 仓库为自建 Gitea（非 GitHub，无需 gh-proxy），私有需要只读密钥：
#   token 从 $HOME/.secrets/ai.env 读取（PI_CONFIG_GIT_TOKEN=...），不进 nix 配置、不提交 git
#   clone 后 origin 移除 token，后续更新走 ~/.git-credentials（容器里挂载宿主机）
# 幂等：已有 .git 跳过 clone。日常同步（pull + fpi-install）不在激活期做：
#   home-manager 在 NixOS 上是开机 oneshot（Before=systemd-user-sessions，卡在 display-manager 之前），
#   开机瞬间网络未就绪，且激活 PATH 缺 npm prefix（${HOME}/.local）会让 fpi-install 误判 pi 未安装
#   而全量重装整个依赖树（实测拖满 2 分钟）。需要同步时手动跑 ~/.pi/agent/bin/fpi-install。
# 启用：本模块默认 enable=false；保留机在机器层显式 softwares.pi.enable = true
#   （modules/home/ai.nix 的默认跟随 pi，机器层无需另写 softwares.ai.enable）

{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.softwares.pi.enable = lib.mkEnableOption "pi agent（配置仓库拉取 + fpi-install 同步）" // {
    default = false;
  };

  config = lib.mkIf config.softwares.pi.enable {
    # pi 本体不随 nix 管理：交由 fpi-install（~/.pi/agent/bin/fpi-install）经 npm 全局安装，走 npmmirror 国内镜像。
    # 故此处不再有 home.packages = [ pkgs.repos.unstable.pi-coding-agent ]。

    # ~/.pi/agent/bin 入 PATH（lib.mkAfter 排在 ~/.local/bin 之后）：
    # fpi/fpi-install/fpi-doctor 等启动器与辅助脚本由 pi-config 仓库管理，nix 不再接管 fpi wrapper
    home.sessionPath = lib.mkAfter [ "$HOME/.pi/agent/bin" ];

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

      }
      setup_pi
    '';
  };
}
