# 机器专属：ficc-test-vm
# 位置：ds3（10.2.241.206）上的 KVM VM（VM ID 200），Ubuntu 24.04，8C/23G/96G，IP 10.2.241.211/24
# 职责：FICC test 环境（迁移自 119.6.62.155:31015-31020）
# 运行时：podman + podman-compose 承载 FICC 中间件（不装 docker，故 softwares.docker.enable = false）
# 中间件 compose 由 middleware.nix 渲染派发到 /data（声明见同目录 compose-mw.yml）
_: {
  softwares = {
    docker.enable = false;
    podman.enable = true;
    sshHostKey.enable = true;
    hostname.enable = true;
  };
}
