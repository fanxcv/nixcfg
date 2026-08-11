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

    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
    };

    # tap 全声明化：禁止手动 brew tap
    mutableTaps = false;

    trust = {
      formulae = [ ];
      casks = [ ];
      commands = [ ];
      taps = [ ];
    };
  };

  homebrew = {
    onActivation = {
      # 未声明的包/cask 自动卸载（从声明清单里移除即删除）
      cleanup = "zap";
    };
  };
}
