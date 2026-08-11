# mini-m4 电源策略（pmset）：用户确认保持实机现状
# 台式机无电池，只设交流供电：永不睡眠 / 10 分钟关屏 / 睡眠跑维护 / 局域网唤醒
# 其他 Mac 不声明电源策略（wanted.yaml 的 macos.all_macs 无 pmset 段）

{ lib, ... }:
let
  inherit (lib.strings) concatStringsSep;
in
{
  system.activationScripts.pmset = {
    text = concatStringsSep " " [
      "pmset -c"
      "sleep 0"          # 永不睡眠
      "displaysleep 10"  # 10 分钟关显示器
      "powernap 1"       # 睡眠时跑维护任务
      "womp 1"           # 局域网唤醒
      "hibernatemode 0"  # 仅内存睡眠
      "standby 0"        # 禁用待机
    ];
  };
}
