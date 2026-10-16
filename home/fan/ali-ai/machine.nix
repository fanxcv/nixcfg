# 机器专属：ali-ai（阿里云 Ubuntu 24.04 服务器，139.224.59.140）
# 公共 hostname/ssh-host-key/tailscale B 路线模块；gitea-act.nix 为 compose+config 渲染派发
_: {
  softwares = {
    sshHostKey.enable = true;
    hostname.enable = true;
    tailscaleB.enable = true;
    pi.enable = true;
  };
}
