# 不可变系统持久化（impermanence）：/persist 只保留需要跨重启的数据
# 根目录是 tmpfs，重启即还原；新增需要持久化的路径在这里登记
_: {
  fileSystems."/persist" = {
    neededForBoot = true;
  };

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      {
        directory = "/etc/nixos";
        mode = "0755";
      }
      {
        directory = "/etc/ssh/keys";
        mode = "0755";
      }
      {
        directory = "/etc/NetworkManager/system-connections";
        mode = "0755";
      }
      {
        directory = "/var/log/journal";
        mode = "0755";
      }
      {
        directory = "/var/lib/nixos";
        mode = "0755";
      }
      {
        directory = "/var/lib/comin";
        mode = "0755";
      }
      {
        directory = "/var/lib/tailscale";
        mode = "0755";
      }
      {
        directory = "/var/lib/NetworkManager";
        mode = "0755";
      }
      {
        directory = "/var/lib/systemd/coredump";
        mode = "0755";
      }
      {
        directory = "/var/lib/systemd/timers";
        mode = "0755";
      }
      {
        directory = "/mnt/code";
        mode = "0755";
      }
      {
        directory = "/opt";
        mode = "0755";
      }
    ];
    files = [
      "/etc/machine-id"
      "/var/lib/systemd/random-seed"
    ];
  };
}
