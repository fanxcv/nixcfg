# unstable 通道注入（pkgs.repos.unstable）：独立的 nixpkgs-unstable 实例
# 给个别需要新版本的包用：vscode 本体 + vscode-extensions 扩展市场（modules/home/vscode.nix）、
#   claude-code（claude.nix）、codex（codex.nix）、pi-coding-agent（pi.nix）
# 锁 rev（flake.lock）+ 周级 nix flake update：unstable 滚动快、二进制保留期短于稳定分支，不更新会掉缓存
#   （周级 update 后 claude-code 版本若升级，overlays/claude-code.nix 的 npmmirror tarball hash
#   可能失效，按注释用 nix-prefetch-url 重算对应平台 hash）
# config 继承主通道（allowUnfreePredicate 白名单同样生效）；claudeOverlay 同步应用——
#   官方 CDN 国内不可达，镜像必须覆盖 unstable 实例的 claude-code（claude.nix 引用 repos.unstable 包）
{ inputs, claudeOverlay }: _: prev: {
  repos = (prev.repos or { }) // {
    unstable = import inputs.unstable {
      inherit (prev) config;
      inherit (prev.stdenv.hostPlatform) system;
      overlays = [ claudeOverlay ];
    };
  };
}
