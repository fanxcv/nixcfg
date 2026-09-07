# 机器专属：hc-pro-pve-2（Ubuntu 24.04 服务器，10.2.241.139，内网）
# 平台配置在 ../_ubuntu_/（继承 _linux_），跨平台在 ../_common_/
# B 路线：系统层归发行版（Ubuntu apt/systemd），nix 管用户态 + 声明派发
# 当前模块：公共 hostname/ssh-host-key/tailscale B 路线模块 + cli-proxy-api.nix（compose+config 渲染派发）

{ tools, ... }:
{
  imports = tools.scan ./.;

  softwares = {
    sshHostKey.enable = true;
    hostname.enable = true;
    tailscaleB = {
      enable = true;
      removeAptPackage = true;
    };
  };
}
