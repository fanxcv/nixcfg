# tmux + gpakosz 配置（对应 docker/ide/ubuntu/Dockerfile 里的 .tmux clone + 定制）
# 与 oh-my-zsh 同套路：activation git clone（gh-proxy 镜像开关由 useChinaMirror 控制），
#   .tmux.conf 软链 + .tmux.conf.local 首次复制 + 追加定制（mouse / base-index）
# 全平台生效（macOS 同样使用）

{ pkgs, lib, tools ? { githubProxy = "https://ghfast.top/"; }, useChinaMirror ? true, ... }:
{
  home.packages = [ pkgs.tmux ];

  home.activation.setupTmux = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_tmux() {
      useProxy="${if useChinaMirror then tools.githubProxy else ""}"

      # 对应 Dockerfile：git clone gpakosz/.tmux
      if [ ! -e "$HOME/.tmux/.git" ]; then
        rm -rf "$HOME/.tmux"
        ${pkgs.git}/bin/git clone --quiet "''${useProxy}https://github.com/gpakosz/.tmux.git" "$HOME/.tmux" \
          || echo "警告: .tmux clone 失败，下次 switch 重试"
      fi

      # 对应 Dockerfile：ln -s -f .tmux/.tmux.conf（已存在则跳过，避免覆盖用户改动）
      if [ ! -e "$HOME/.tmux.conf" ]; then
        ln -sf "$HOME/.tmux/.tmux.conf" "$HOME/.tmux.conf"
      fi

      # 对应 Dockerfile：cp .tmux.conf.local（仅首次，用户可自行修改）
      if [ ! -e "$HOME/.tmux.conf.local" ]; then
        cp "$HOME/.tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
      fi

      # 对应 Dockerfile 追加的两行定制（幂等：已存在不重复追加）
      grep -q '^set -g mouse on$' "$HOME/.tmux.conf.local" \
        || echo 'set -g mouse on' >> "$HOME/.tmux.conf.local"
      grep -q '^set -g base-index 1$' "$HOME/.tmux.conf.local" \
        || echo 'set -g base-index 1' >> "$HOME/.tmux.conf.local"
    }
    setup_tmux
  '';
}
