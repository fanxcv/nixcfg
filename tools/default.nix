# 工具集合（flake.nix 注入 specialArgs.tools，模块里用 { tools, ... } 取用）
{ lib, self }:
let
  # 全局镜像/代理集中配置（唯一配置入口，见 config.nix）
  config = import ./config.nix;
in
{
  inherit config;
  # GitHub 加速前缀（便捷键，等价 config.githubProxy）
  githubProxy = config.githubProxy;
  # 国内镜像开关（flake.nix 注入 useChinaMirror 的默认值；机器级可经 mkHomeConfig/mkDarwinConfig 参数覆盖）
  useChinaMirror = config.useChinaMirror;

  # 给 GitHub URL 套加速前缀：命中 withoutProxy 例外或 githubProxy 为空（直连模式）时不套
  githubUrl = url:
    if config.githubProxy == ""
    || lib.lists.any (ex: lib.strings.hasPrefix ex url) config.withoutProxy
    then url
    else config.githubProxy + url;

  # fetchFromGitHub 的 githubBase（无 scheme 子串形式，packages/ 包构建用）
  #   https://ghfast.top/ → ghfast.top/https://github.com（内部拼 https://${githubBase}/...）
  #   直连（githubProxy 空）→ github.com
  githubFetchBase =
    if config.githubProxy == "" then "github.com"
    else lib.strings.removePrefix "https://" config.githubProxy + "https://github.com";

  scan = import ./scan.nix { inherit lib; };
  relative = import ./relative.nix { inherit self; };

  # syncthing 互配机器清单（单一事实来源，见 syncthingPeers.nix）
  syncthingPeers = import ./syncthingPeers.nix;
  # syncthing 自动注册脚本生成器（darwin activation / nixos oneshot 共用）
  syncthingAutoConfig = import ./syncthingAutoConfig.nix;
}