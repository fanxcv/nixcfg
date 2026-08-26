# OrbStack（容器运行时）声明式配置注入（macOS 三台共享）
# 提取自 mba-m5 实机（orb config show 与落盘文件对照后，非默认项）：
#   vmconfig.json         memory_mib=8192  内存上限 8G（OrbStack 只在值≠默认时落盘此文件，实机落盘=显式设置）
#   config/docker.json    registry-mirrors 三个国内镜像加速（daemon.json 风格，orb config docker 编辑）
#                         ——挂 useChinaMirror 开关（flake.nix 注入，与 mirrors.nix 同语义；false 时不注入）
#   defaults SUAutomaticallyUpdate=0  关闭自动下载更新（Sparkle 键，域 dev.kdrag0n.MacVirt）
# 其余 orb config 项（docker.expose_ports_to_lan/machines.expose_ports_to_lan/app.start_at_login
#   等）经 set-默认值实验确认为默认行为，无需声明
# 生效时机：vmconfig/docker.json 需 orb stop && orb start（或 orb restart docker）；defaults 重启 App 生效
{
  pkgs,
  lib,
  tools,
  useChinaMirror ? true,
  ...
}:
let
  # 国内镜像三连（useChinaMirror=false 时传空，apply.py 跳过 docker.json，保持用户现状）
  dockerMirrors =
    if useChinaMirror then lib.concatStringsSep " " tools.config.dockerRegistryMirrors else "";
in
{
  home.activation.setupOrbstack = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${./orbstack/apply.py} \
      "$HOME/.orbstack" "8192" "${dockerMirrors}"
    defaults write dev.kdrag0n.MacVirt SUAutomaticallyUpdate -bool false
    if [ -x /opt/homebrew/bin/orb ] && pgrep -q -f "OrbStack.app/Contents/MacOS/OrbStack"; then
      echo "orbstack: 配置已写入——orb stop && orb start（或 orb restart docker）、重启 App 后生效"
    fi
  '';
}
