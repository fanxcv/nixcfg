# 机器专属：ficc-test-pve
# 位置：ds3（10.2.241.206）上的 PVE LXC（CT 100），Ubuntu 24.04，8C/24G/100G，IP 10.2.241.210/24
# 职责：FICC test 环境（迁移自 119.6.62.155:31015-31020）
# 运行时：docker + docker-compose 承载 FICC 中间件
#   选 docker 非 podman：LXC unprivileged 的嵌套 userns 下，podman 的 netavark 起网络时
#   socket() 返回 EACCES（容器内 bind 端口失败），docker 走标准 netns/bridge 实测全通
# 中间件 compose 由 middleware.nix 渲染派发到 /data（声明见同目录 compose-mw.yml）
_: {
  softwares = {
    docker = {
      enable = true;
      # LXC 内无发行版 docker：由本模块生成 docker.service / docker.socket（nix 的 dockerd）
      adoptSystem = true;
    };
    podman.enable = false;
    sshHostKey.enable = true;
    hostname.enable = true;
  };
}
