# Clash Verge Rev（代理客户端）声明式配置注入（macOS 三台共享）
# 三件套激活期幂等收敛（→ clash-verge/apply.py）：
#   verge.yaml        App 设置：开机自启/静默启动/混合端口 7890/DNS 覆写关闭
#   clash-verge.yaml  Clash 设置页：mixed-port 7890 / allow-lan / ipv6=false
#   profiles.yaml     订阅列表：注入远程订阅（uuid5(url) 确定性 uid）并设为 current，下载订阅内容
# 文件不存在时按模板补写（App 首启即可读）；已符合则跳过，可重复执行
# 注意：App 运行中不热重载——部署后重启 Clash Verge 生效（脚本只提示，不 killall）
{ pkgs, lib, ... }:
{
  home.activation.setupClashVerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${./clash-verge/apply.py} \
      "$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev" \
      "https://xx.fan-x.eu.org/api/v1/client/subscribe?token=eaa63ab248c016278df7f8f6d2847757" \
      "7890" "true" "true" "true" "false" "false"
    if pgrep -f "Clash Verge" >/dev/null 2>&1; then
      echo "clash-verge: App 运行中——配置已写入，重启 App 后完整生效"
    fi
  '';
}
