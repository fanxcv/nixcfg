# syncthing（P2P 文件同步）——nix-pve：系统级服务，以 fan 用户身份运行
#   目录落在持久层：configDir → ~/.config（已持久化）、dataDir → ~/.local（已持久化），
#     数据目录 ~/sync 见 home/fan/nix-pve/immutable.nix
#   GUI 仅绑 127.0.0.1（本机浏览器/SSH 隧道）；openFirewall 放行 22000/21027
#   设备配对走 GUI（各机 127.0.0.1:8384 互加，地址填 tailscale IP，`tailscale ip -4` 查询）
#   配置由 syncthing 自管（不声明式，避免 rebuild 覆盖 GUI 配对状态）
_: {
  services.syncthing = {
    enable = true;
    user = "fan";
    group = "users";
    dataDir = "/home/fan/.local/state/syncthing";
    configDir = "/home/fan/.config/syncthing";
    guiAddress = "127.0.0.1:8384";
    # GUI 登录密码（明文文件由 agenix 解密到 /run/agenix/，模块自动 bcrypt 后经 REST API 注入；
    # 声明式 merge 不覆盖 config.xml，GUI 配对状态保留）
    guiPasswordFile = "/run/agenix/syncthing-gui-password";
    openDefaultPorts = true; # 放行 22000 TCP/UDP + 21027/UDP（26.05 模块旧名 openFirewall 已改名）
  };
}
