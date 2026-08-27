# syncthing（P2P 文件同步）——nix-book：系统级服务，以 fan 用户身份运行
#   目录落在持久层：configDir → ~/.config（已持久化）、dataDir → ~/.local（已持久化），
#     数据目录 ~/sync 见 home/fan/nix-book/immutable.nix
#   GUI 仅绑 127.0.0.1（本机浏览器/SSH 隧道）；openDefaultPorts 放行 22000/21027
#   设备互配：syncthing-autoregister oneshot（syncthing 启动后自动跑，清单 tools/syncthingPeers.nix）
#   配置由 syncthing 自管（脚本仅补缺不删改，rebuild 不覆盖 GUI 配对状态）
#   GUI 密码：agenix 解密到 /run/agenix/syncthing-gui-password（fan 可读），oneshot 注入 user=fan+password
#     （nixpkgs 模块 guiPasswordFile 只 PATCH password 不设 user，syncthing 要求双非空才启用认证，故必须自注入）
{
  pkgs,
  tools,
  ...
}:
let
  peers = tools.syncthingPeers;
  # 自动注册脚本（设备互配 + ~/sync folder + GUI 密码注入）
  autoConfigScript = tools.syncthingAutoConfig {
    inherit pkgs peers;
    guiPasswordFile = "/run/agenix/syncthing-gui-password";
  };
in
{
  services.syncthing = {
    enable = true;
    user = "fan";
    group = "users";
    dataDir = "/home/fan/.local/state/syncthing";
    configDir = "/home/fan/.config/syncthing";
    guiAddress = "127.0.0.1:8384";
    # GUI 登录密码（明文文件由 agenix 解密到 /run/agenix/，模块每次服务启动自动 bcrypt 注入；
    # 改密码 = 更新 secret + 重启 syncthing 服务）
    guiPasswordFile = "/run/agenix/syncthing-gui-password";
    openDefaultPorts = true; # 放行 22000 TCP/UDP + 21027/UDP（26.05 模块旧名 openFirewall 已改名）
  };

  # 自动注册 oneshot：syncthing 启动后执行，幂等补缺（设备互配 + ~/sync folder）
  systemd.services.syncthing-autoregister = {
    description = "Syncthing 自动注册（设备互配 + ~/sync folder）";
    after = [ "syncthing.service" ];
    requires = [ "syncthing.service" ];
    wantedBy = [ "syncthing.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "fan";
      Group = "users";
      ExecStart = "${pkgs.writeShellScript "syncthing-autoregister" autoConfigScript}";
      Restart = "on-failure"; # syncthing 未就绪时重试
      RestartSec = 30;
    };
  };
}
