# 机器专属：ali-ai（阿里云 Ubuntu 24.04 服务器，139.224.59.140）
# 平台配置在 ../_ubuntu_/（继承 _linux_），跨平台在 ../_common_/
# B 路线：系统层归发行版（Ubuntu apt/systemd），nix 管用户态 + 声明派发
# 当前模块：tailscale.nix（docker → nix 接管）、gitea-act.nix（compose+config 渲染派发）

{ tools, ... }:
{
  imports = tools.scan ./.;
}
