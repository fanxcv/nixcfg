# nix-homebrew：Homebrew 声明式管理
#   - taps 全声明化（mutableTaps = false，不能再手动 brew tap）
#   - cleanup = "zap"：未在声明列表里的 formulae/casks 下次激活自动卸载
#   - casks 清单在 apps.nix（三台 Mac 公共；个别机器差异化时移到 hosts/<host>/homebrew.nix）

{ inputs, config, ... }:
let
  inherit (inputs) homebrew-core homebrew-cask cirruslabs-cli;
in
{
  nix-homebrew = {
    # 默认前缀安装（/opt/homebrew）
    enable = config.homebrew.enable;

    # Apple Silicon 机型，无需 Rosetta（需要跑 x86 应用时改 true 并确认已装 Rosetta）
    enableRosetta = false;

    # Homebrew prefix 属主（nix-darwin 的 primaryUser = fan）
    user = config.system.primaryUser;

    # 全新部署遇已有 Homebrew（如 tart 预装镜像）时自动迁移接管，不打断激活
    autoMigrate = true;

    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      # 必须用完整仓库名（brew 6 按 user/homebrew-<repo> 推导 tap 目录）；
      # 实机当年手动 brew tap 留下的 homebrew-cli 目录恰好一致，全新部署重放验证暴露
      "cirruslabs/homebrew-cli" = cirruslabs-cli; # tart 等（mini-m4 用）
    };

    # tap 全声明化：禁止手动 brew tap
    mutableTaps = false;

    # bottles 走国内镜像（USTC）；cask 的 app 安装包无镜像，仍走代理
    extraEnv = {
      HOMEBREW_BOTTLE_DOMAIN = "https://mirrors.ustc.edu.cn/homebrew-bottles";
    };

    trust = {
      # tap 整体信任：全新部署时 brew 拒绝 untrusted tap 的 formula（实机因包已装未触发，
      # 重放验证暴露）；激活时执行 brew trust --tap
      taps = [ "cirruslabs/cli" ];
      formulae = [ ];
      casks = [ ];
      commands = [ ];
    };
  };

  homebrew = {
    # Brewfile Taps 区段：与 nix-homebrew.taps 对齐，否则 bundle --zap 每次想 untap
    # 已装 casks 的 tap（重放验证暴露：Refusing to untap homebrew/cask）
    taps = [
      "homebrew/homebrew-core"
      "homebrew/homebrew-cask"
      "cirruslabs/homebrew-cli"
    ];
    onActivation = {
      # 未声明的包/cask 自动卸载（从声明清单里移除即删除）
      cleanup = "zap";
    };
  };
}
