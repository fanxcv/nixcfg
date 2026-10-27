# 机器专属：hc-test-pve
# 位置：10.2.241.65（PVE LXC，16C/16G，盘剩 17G）
# 现状：已跑 12 个 docker 容器（gitea/postgres/mysql5.7/redis/caddy/hc-java/hc-go 等），原由 apt docker-ce 管理
# 策略：docker 交 nix 接管（adoptSystem）：停用并卸载 apt docker-ce/containerd.io，daemon 换 nix 渲染的 unit；
#   /var/lib/docker 原地复用，12 个容器与网络/卷全在，restart=always 自动回，无需重建
# tailscale：接管 apt tailscale 1.96.4（state 由 secrets/hosts/hc-test-pve/tailscale-state.age 恢复），
#   节点名/IP 保持不变（tailnet 10.1.0.30）
_: {
  softwares = {
    docker = {
      enable = true;
      adoptSystem = true;
    };
    sshHostKey.enable = true;
    hostname.enable = true;
    tailscaleB = {
      enable = true;
      removeAptPackage = true;
    };
  };
}
