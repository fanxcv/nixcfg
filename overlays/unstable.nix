# unstable 通道注入（pkgs.repos.unstable）：独立的 nixpkgs-unstable 实例
# 只给个别需要新版本的包用（vscode 本体 + vscode-extensions 扩展市场，见 modules/home/vscode.nix）
# 锁 rev（flake.lock）+ 周级 nix flake update：unstable 滚动快、二进制保留期短于稳定分支，不更新会掉缓存
# config 继承主通道（allowUnfreePredicate 白名单同样生效）
{ inputs, ... }: _: prev: {
  repos = (prev.repos or { }) // {
    unstable = import inputs.unstable {
      inherit (prev) config;
      inherit (prev.stdenv.hostPlatform) system;
    };
  };
}
