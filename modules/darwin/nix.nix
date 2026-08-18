# nix 配置（系统级）：国内镜像 substituters + cachix 补充（与 flake.nix 的 nixConfig 一致）
# nix-darwin 激活时写入 /etc/nix/nix.conf；全新部署无需手动配置即可走镜像
# 自 hosts/_darwin_/base/nix.nix 迁入（modules/darwin 模块库）
{
  nix.settings = {
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    experimental-features = [ "nix-command" "flakes" ];
    # 继承 Nix 安装器的手写配置（旧 /etc/nix/nix.conf）：admin 组用户视为可信
    trusted-users = [ "root" "@admin" ];
  };
}
