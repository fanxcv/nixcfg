# skemate（自研终端复用服务）安装门控选项
# 只定义选项；安装/配置/自启逻辑留在机器层（home/fan/mini-m4/skemate.nix、
# home/fan/_container_/skemate.nix），装 skemate 的机器设 softwares.skemate.enable = true。
# 用途：shells.nix 按此门控部署命令是否带 --impure——只有装 skemate 的机器，
#       eval 会触达 overlays/skemate.nix 的 eval 期 fetchurl（latest.json），才需要 --impure。
{
  lib,
  ...
}:
{
  options.softwares.skemate.enable = lib.mkEnableOption "skemate 终端复用服务（安装即部署须 --impure）";
}
