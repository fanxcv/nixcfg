# syncthing（P2P 文件同步）——三台 Mac 公共（brew formula 见 hosts/_darwin_/base/homebrew.nix）
#   服务：LaunchAgent 自启（RunAtLoad + KeepAlive），登录即启、崩溃自动重启
#   同步：两个目录——
#     ~/sync  仅现有机器之间（清单 tools/syncthingPeers.nix 的 peers）
#     ~/share 全部机器（peers + idePeers，即含三个 ide 容器）
#   设备互配由 activation 幂等脚本自动完成（清单 tools/syncthingPeers.nix 单一事实来源）
#   注意：syncthing 配置（config.xml）由 syncthing 自管；自动注册脚本仅补缺不删改（GUI 配对保留），
#         惟 tools/syncthingPeers.nix 的 retired 清单内设备会被删除
{
  pkgs,
  lib,
  tools,
  ...
}:
let
  inherit (tools.syncthingPeers) peers idePeers retired;
  peerIds = map (p: p.id) peers;
  shareIds = peerIds ++ map (p: p.id) idePeers;
  autoConfigScript = tools.syncthingAutoConfig {
    inherit pkgs peers retired;
    extraPeers = idePeers;
    folders = [
      {
        id = "sync";
        label = "sync";
        devices = peerIds;
      }
      {
        id = "share";
        label = "share";
        devices = shareIds;
      }
    ];
    # GUI 密码（QAZxsw2341 源）age 解密 → PUT；放脚本末尾（PUT 触发 syncthing 重启）
    guiPasswordAgePath = "${../../..}/secrets/syncthing-gui-password.age";
  };
in
{
  # 同步目录（.keep 占位触发 home-manager 建目录）
  home.file."sync/.keep".text = "";
  home.file."share/.keep".text = "";

  # 忽略规则（.stignore）在 ../_common_/syncthing.nix（darwin/nixos 门控）

  # LaunchAgent：登录即启 + KeepAlive 常驻（改配置后 launchctl kickstart -k gui/$(id -u)/syncthing 重启）
  # --no-browser：不弹浏览器；日志 syncthing 自管（配置目录 syncthing.log），不设 StandardOutPath
  launchd.agents.syncthing = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/syncthing"
        "serve"
        "--no-browser"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = "/Users/fan";
    };
  };

  # 自动注册（幂等，entryAfter writeBoundary）：
  #   ① 注册 peers+idePeers 清单缺失设备（缺者补，GUI 已有配对不动）
  #   ② ~/sync 与 ~/share folder 无则建（各按清单 devices）、有则补缺设备、path 纠正
  #   ③ GUI 密码经 age 解密注入（每次都 PUT，密码变更随部署生效；失败仅警告）
  home.activation.setSyncthingAutoConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] autoConfigScript;
}
