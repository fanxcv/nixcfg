# 电源策略（pmset）：电池/交流两套独立配置
# 由 system.activationScripts 在激活时写入
{ lib, ... }:
let
  inherit (lib.strings) concatStringsSep;

  pmsetCommands = [
    # ---- 电池供电 ----
    [
      "pmset -b"
      "hibernatemode 0"       # 仅内存睡眠，不写休眠镜像
      "standby 0"             # 禁用长时间睡眠后的待机
      "autopoweroff 0"        # 禁用自动断电
      "powernap 0"            # 睡眠时不跑维护任务
      "tcpkeepalive 0"        # 睡眠时不维持 TCP（省电）
      "womp 0"                # 禁用局域网唤醒
      "sleep 3"               # 空闲 3 分钟睡眠
      "displaysleep 3"        # 空闲 3 分钟关显示器
      "lessbright 1"          # 电池时自动降亮度
      "lidwake 1"             # 开盖唤醒
    ]

    # ---- 交流供电 ----
    [
      "pmset -c"
      "hibernatemode 0"
      "standby 0"
      "autopoweroff 0"
      "powernap 0"
      "tcpkeepalive 1"        # 插电时保留 TCP keepalive
      "womp 0"
      "sleep 10"              # 空闲 10 分钟睡眠
      "displaysleep 5"        # 空闲 5 分钟关显示器
      "lidwake 1"
    ]
  ];
in
{
  system.activationScripts.pmset = {
    # 每个场景一行命令（空格拼接），换行分隔不同场景
    text = concatStringsSep "\n" (map (concatStringsSep " ") pmsetCommands);
  };
}
