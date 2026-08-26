# nix 配置（系统级）：国内镜像 substituters + cachix 补充（列表集中 tools/config.nix）
# nix-darwin 激活时写入 /etc/nix/nix.conf；全新部署无需手动配置即可走镜像
# 自 hosts/_darwin_/base/nix.nix 迁入模块库
{ tools, ... }:
{
  nix.settings = {
    substituters = tools.config.nixSubstituters;
    extra-substituters = tools.config.nixCachixSubstituters;
    extra-trusted-public-keys = tools.config.nixCachixTrustedPublicKeys;
    experimental-features = [ "nix-command" "flakes" ];
    # 继承 Nix 安装器的手写配置（旧 /etc/nix/nix.conf）：admin 组用户视为可信
    trusted-users = [ "root" "@admin" ];
  };

  # 自动 GC（30 天保留，每周）+ 定期硬链接优化（nix-darwin 原生定时器）
  nix.gc.automatic = true;
  nix.gc.interval = { Day = 7; };
  nix.gc.options = "--delete-older-than 30d";
  nix.optimise.automatic = true;
  nix.optimise.interval = { Day = 7; };
}
