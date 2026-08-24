# syncthing（P2P 文件同步）——三台 Mac 公共（brew formula 见 hosts/_darwin_/base/homebrew.nix）
#   服务：LaunchAgent 自启（RunAtLoad + KeepAlive），登录即启、崩溃自动重启
#   同步：~/sync 目录与 nix-pve 及其他 Mac 组网；设备互配由 activation 幂等脚本自动完成
#     （清单 tools/syncthingPeers.nix 单一事实来源，新增机器登记后各机下次部署自动互配）
#   注意：syncthing 配置（config.xml）由 syncthing 自管；自动注册脚本仅补缺不删改（GUI 配对保留）
{
  pkgs,
  lib,
  tools,
  ...
}:
let
  peers = tools.syncthingPeers;
  autoConfigScript = tools.syncthingAutoConfig {
    inherit pkgs peers;
    # GUI 密码（QAZxsw2341 源）age 解密 → PUT；放脚本末尾（PUT 触发 syncthing 重启）
    guiPasswordAgePath = "${../../..}/secrets/syncthing-gui-password.age";
  };
in
{
  # ~/sync 同步目录（.keep 占位触发 home-manager 建目录）
  home.file."sync/.keep".text = "";

  # LaunchAgent：登录即启 + KeepAlive 常驻（改配置后 launchctl kickstart -k gui/$(id -u)/syncthing 重启）
  # --no-browser：不弹浏览器；日志 syncthing 自管（配置目录 syncthing.log），不设 StandardOutPath
  launchd.agents.syncthing = {
    enable = true;
    config = {
      ProgramArguments = [ "/opt/homebrew/bin/syncthing" "serve" "--no-browser" ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = "/Users/fan";
    };
  };

  # 自动注册（幂等，entryAfter writeBoundary）：
  #   ① 注册 peers 清单缺失设备（缺者补，GUI 已有配对不动）
  #   ② ~/sync folder 无则建（共享清单全部+本机）、有则补缺设备、path 纠正
  #   ③ GUI 密码经 age 解密注入（每次都 PUT，密码变更随部署生效；失败仅警告）
  home.activation.setSyncthingAutoConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] autoConfigScript;
}
