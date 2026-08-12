# 开发工具国内镜像（npm/pip/uv，挂 useChinaMirror 开关）
#   useChinaMirror=true（默认，所有 ide 容器）→ npm→npmmirror、pip/uv→清华 TUNA
#   useChinaMirror=false（NixOS 真机国外直连场景）→ 不写配置文件，工具默认官方源
# 用配置文件而非环境变量：npm/pip/uv 自动读取，不依赖 shell 环境加载

{ lib, useChinaMirror ? true, ... }:
{
  # ~/.npmrc：mise 装的 node 的 npm/pnpm/yarn 均读此文件
  # ~/.config/pip/pip.conf：pip 用户级配置（XDG 路径，https 源证书有效无需 trusted-host）
  # ~/.config/uv/uv.toml：uv 用户级配置（index-url 键自 uv 0.1 起均支持）
  home.file = lib.mkIf useChinaMirror {
    ".npmrc".text = "registry=https://registry.npmmirror.com\n";
    ".config/pip/pip.conf".text = ''
      [global]
      index-url = https://pypi.tuna.tsinghua.edu.cn/simple
    '';
    ".config/uv/uv.toml".text = ''
      index-url = "https://pypi.tuna.tsinghua.edu.cn/simple"
    '';
  };
}
