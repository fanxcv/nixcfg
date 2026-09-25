# nix-homebrew：Homebrew 声明式管理
#   - taps 全声明化（mutableTaps = false，不能再手动 brew tap）
#   - cleanup = "zap"：未在声明列表里的 formulae/casks 下次激活自动卸载
#   - casks 清单在 apps.nix（三台 Mac 公共；个别机器差异化时移到 hosts/<host>/homebrew.nix）

{ inputs, config, ... }:
let
  inherit (inputs) homebrew-core homebrew-cask;
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
      # cirruslabs/cli tap 已移除：上游 tart.rb 旧语法被 Homebrew 禁用，tart 改 nixpkgs 原生包
      # （hosts/mini-m4/homebrew.nix environment.systemPackages）
    };

    # tap 全声明化：禁止手动 brew tap
    mutableTaps = false;
    # 网络策略：bottles 走国内镜像（CERNET）；cask 的 app 安装包无镜像，由用户侧代理环境变量自行处理
    extraEnv = {
      HOMEBREW_BOTTLE_DOMAIN = "https://mirrors.cernet.edu.cn/homebrew-bottles";
    };
  };

  homebrew = {
    # Brewfile Taps 区段：与 nix-homebrew.taps 对齐，否则 bundle --zap 每次想 untap
    # 已装 casks 的 tap（重放验证暴露：Refusing to untap homebrew/cask）
    taps = [
      "homebrew/homebrew-core"
      "homebrew/homebrew-cask"
    ];
    # brew 命令行公式（三台 Mac 公共；自启走 launchd.agents → home/fan/_darwin_/syncthing.nix）
    brews = [
      "syncthing" # P2P 文件同步（多机组网，~/sync）
    ];
    onActivation = {
      # 未声明的包/cask 自动卸载（从声明清单里移除即删除）
      cleanup = "zap";
    };
  };
}
