# 跨平台基础配置（所有机器通用）
# 对应 alpine-init.sh 的 install_packages()：
#   zsh 由 shells.nix 的 programs.zsh 安装（不装包）
#   git/vim/curl 是 Linux 平台包（mac 自带）→ _linux_/base.nix
#   rg/fd/jq/rtk 由 nix 直接管理（全平台；mac 的 mise 手配如重复请手动清理）

{ pkgs, ... }:
{
  # 所有平台统一加入 ~/.local/bin（用户本地脚本目录；mise shims 见 mise.nix）
  # ~/.pi/agent/bin 由 pi.nix 用 lib.mkAfter 追加（见 home/fan/_common_/pi.nix）
  home.sessionPath = [ "$HOME/.local/bin" ];

  # CLI 工具统一由 nix 管理（rg/fd/jq/rtk 原由 mise 安装，改回 nix 包）
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    rtk
    # 终端工作流：模糊搜索/智能 cd/环境加载/高亮 cat/现代 ls/yaml 处理
    fzf
    zoxide
    direnv
    bat
    eza
    yq
    # TUI 版 git（lazygit，所有机器；配置文件 ~/.config/lazygit/config.yml 用户自管）
    lazygit
    # 系统信息展示（所有机器；neofetch 已从 nixpkgs 移除，fastfetch 为社区标准替代）
    fastfetch
    # 默认 node 由 nix 管理（替代原全局默认 mise node@lts，pkgs.nodejs 跟随 nixpkgs LTS）；
    # 机器级 mise node（mini-m4@24 / ide 容器@22）经 shims 覆盖全局，见 mise.nix
    nodejs
  ];

  programs.git = {
    enable = true;
    # 对应脚本里的 git config --global（只生成 ~/.gitconfig，不安装 git 本身）
    # 新版 hm 统一用 settings（userName/userEmail/extraConfig 已弃用）
    settings = {
      user = {
        name = "fan";
        email = "fan@fan-x.fun";
      };
      credential.helper = "store";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true; # 新分支首次 push 自动建远端跟踪
      fetch.prune = true; # fetch 时清理已删远端分支
      rerere.enabled = true; # 冲突解决记忆（同冲突只解一次）
      # 配置仓库挂载自宿主机，owner 可能与容器用户不同，避免 dubious ownership 报错
      # /etc/nixos = NixOS 机器仓库（/persist/etc/nixos 挂载，root 所有），fan 用户 git 操作需放行
      safe.directory = [ "/root/nixcfg" "/etc/nixos" ];
    };
  };
}
