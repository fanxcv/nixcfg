{ lib, ... }:
{
  # 全平台统一北京时间（docker 容器 TZ 也是 Asia/Shanghai）
  time.timeZone = lib.mkDefault "Asia/Shanghai";
}
