# Homebrew casks 清单（GUI 应用，三台 Mac 公共）
# 由 wanted.yaml 的 macos.all_macs.apps 维护：改清单后同步即可
# 从清单移除 = 下次 darwin-rebuild 自动卸载；个别机器差异化时：
#   把该机器要增减的条目移到 hosts/<host>/homebrew.nix 用 lib.mkAfter 追加
_: {
  homebrew.enable = true;
  homebrew.casks = [
    { name = "orbstack"; }       # 容器运行时（三台 Mac 统一）
    { name = "iterm2"; }         # 终端
    { name = "microsoft-edge"; } # 浏览器
    { name = "rustdesk"; }       # 远程控制（自建中继）
    { name = "tencent-lemon"; }  # 系统清理
    { name = "bitwarden"; }       # 密码管理
    { name = "tailscale-app"; }   # 组网（App 版；旧名 tailscale 已被 homebrew 重命名）
    { name = "clash-verge-rev"; } # 代理客户端
  ];
}
