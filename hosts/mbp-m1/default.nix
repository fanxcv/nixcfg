# MacBook Pro（M1）—— 机器组装清单
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
