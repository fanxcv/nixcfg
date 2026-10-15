# home 目录持久化（/persist/home/fan）：tmpfs 根下 home 数据跨重启保留
# nix-pve/nix-lenovo 共用（home/fan/_nixos_/default.nix 用 tools.scan 扫描导入）
# 注意 .oh-my-zsh 是 git clone 安装（非 nix 包，见 _common_/shells.nix），必须持久化
_: {
  home.persistence."/persist" = {
    directories = [
      {
        directory = ".ssh";
        mode = "0700";
      }
      {
        directory = ".secrets";
        mode = "0700";
      }
      {
        directory = ".oh-my-zsh";
        mode = "0755";
      }
      {
        directory = ".config";
        mode = "0755";
      }
      {
        directory = ".cache";
        mode = "0755";
      }
      {
        directory = ".local";
        mode = "0755";
      }
      {
        directory = ".npm";
        mode = "0755";
      }
      {
        directory = ".claude";
        mode = "0755";
      }
      {
        directory = ".codex";
        mode = "0755";
      }
      {
        directory = ".pi";
        mode = "0755";
      }
      {
        directory = "codebases";
        mode = "0755";
      }
      {
        directory = "sync"; # syncthing 同步目录（仅现有机器之间）
        mode = "0755";
      }
      {
        directory = "share"; # syncthing 共享目录（全部机器，含 ide 容器）
        mode = "0755";
      }
      {
        directory = "downloads";
        mode = "0755";
      }
      {
        directory = "roms"; # Switch ROM 库（eden）；persist 卷 2026-10-10 扩至 400G
        mode = "0755";
      }
      {
        directory = "xwechat_files"; # 微信 4.x 数据目录（仅 nix-lenovo 装微信，nix-pve 上为空目录）
        mode = "0755";
      }
    ];
    files = [
      ".claude.json"
      ".zsh_history" # zsh 历史（oh-my-zsh 默认路径），tmpfs 根下跨重启保留
    ];
  };
}
