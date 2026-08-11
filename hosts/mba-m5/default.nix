# MacBook Air（M5）—— 机器组装清单
# 公共配置都在 hosts/_common_/ + hosts/_darwin_/，本目录只放本机特有项
{ tools, ... }:
{
  imports =
    (map tools.relative [
      "hosts/_common_/base"
      "hosts/_common_/i18n"
      "hosts/_darwin_/base"
      "hosts/_darwin_/gui"
      "hosts/_darwin_/i18n"
      "hosts/_darwin_/kernel"
      "hosts/_darwin_/services"

      "users/fan"
    ])
    ++ (tools.scan ./.);
}
