# 语言环境：基础语言 en_US（终端/SSH 保持英文输出；中文显示由应用层字体/输入法处理）
# KDE 界面中文由 _nixos_/i18n/zh-CN/plasma-localerc.nix 声明（Language=zh_CN，不随 LANG 变化）
# 仅 darwin/nixos 真机原本启用该值 → 门控之，容器（localedef 自管 locale）/PVE 主机行为不变
{ lib, platform, ... }:
lib.mkIf (platform == "darwin" || platform == "nixos") {
  home.language.base = lib.mkDefault "en_US.UTF-8";
}
