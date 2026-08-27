# home 目录持久化（/persist/home/fan）：tmpfs 根下 home 数据跨重启保留
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
        directory = "sync"; # syncthing 同步目录（与三台 Mac 组网）
        mode = "0755";
      }
      {
        directory = "downloads";
        mode = "0755";
      }
    ];
    files = [
      ".claude.json"
    ];
  };
}
