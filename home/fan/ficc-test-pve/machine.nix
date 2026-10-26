# 机器专属：ficc-test-pve
# 位置：ds3（10.2.241.206）上的 PVE LXC，Ubuntu 24.04，8C/24G/98G，IP 10.2.241.210/24
# 职责：FICC test 环境（迁移自 119.6.62.155:31015-31020）
# 运行时：podman + podman-compose（不装 docker），故 softwares.docker.enable = false
_: {
  softwares = {
    docker.enable = false;
    sshHostKey.enable = true;
    hostname.enable = true;
  };
}
