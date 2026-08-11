# 跨平台基础配置（所有机器通用）
# 对应 alpine-init.sh 的 install_packages()：
#   zsh 由 shells.nix 的 programs.zsh 安装（不装包）
#   git/vim/curl 是 Linux 平台包（mac 自带）→ _linux_/base.nix
#   rg/fd/jq/rtk 由 nix 直接管理（全平台；mac 的 mise 手配如重复请手动清理）

{ pkgs, ... }:
{
  # 所有平台统一加入 ~/.local/bin（用户本地脚本目录；mise shims 见 mise.nix）
  home.sessionPath = [ "$HOME/.local/bin" ];

  # CLI 工具统一由 nix 管理（rg/fd/jq/rtk 原由 mise 安装，改回 nix 包）
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    rtk
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
      # 配置仓库挂载自宿主机，owner 可能与容器用户不同，避免 dubious ownership 报错
      safe.directory = "/root/nixcfg";
    };
  };
}
