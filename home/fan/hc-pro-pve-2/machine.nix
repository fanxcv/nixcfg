# 机器专属：hc-pro-pve-2（Ubuntu 24.04 服务器，10.2.241.139，内网）
# 公共 hostname/ssh-host-key/tailscale B 路线模块；cli-proxy-api.nix 为 compose+config 渲染派发
_: {
  softwares = {
    sshHostKey.enable = true;
    hostname.enable = true;
    tailscaleB = {
      enable = true;
      removeAptPackage = true;
    };
  };
}
