# 机器专属：hc-test-pve
# 位置：10.2.241.65（PVE LXC，16C/16G，盘剩 17G）
# 现状：已跑 12 个 docker 容器（gitea/postgres/mysql5.7/redis/caddy/hc-java/hc-go 等），均由 apt docker 管理
# 策略：保留原有 docker 不动，故 softwares.docker.enable = false（避免 nix 版 docker 与既有 daemon 冲突）
# tailscale：接管 apt tailscale 1.96.4（state 由 secrets/hosts/hc-test-pve/tailscale-state.age 恢复），
#   节点名/IP 保持不变（tailnet 10.1.0.30）
_: {
  softwares = {
    docker.enable = false;
    sshHostKey.enable = true;
    hostname.enable = true;
    tailscaleB = {
      enable = true;
      removeAptPackage = true;
    };
  };
}
