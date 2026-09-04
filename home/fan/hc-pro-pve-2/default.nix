# 机器专属：hc-pro-pve-2（Ubuntu 24.04 服务器，10.2.241.139，内网）
# 平台配置在 ../_ubuntu_/（继承 _linux_），跨平台在 ../_common_/
# B 路线：系统层归发行版（Ubuntu apt/systemd），nix 管用户态 + 声明派发
# 当前模块：hostname.nix（hostnamectl 固定）、ssh-host-key.nix（host key 接管）、
#   tailscale.nix（apt 系统包 → nix 接管）、cli-proxy-api.nix（compose+config 渲染派发）

{ tools, ... }:
{
  imports = tools.scan ./.;
}
