# 开发工具国内镜像（npm/pip/uv/go/flutter，挂 useChinaMirror 开关，所有机器通用）
#   useChinaMirror=true（默认，ide 容器 / mini-m4 等）→ npm→npmmirror、pip/uv→清华 TUNA、
#     go→goproxy.cn、flutter→flutter-io.cn 镜像
#   useChinaMirror=false（国外直连场景）→ 不写配置文件/不注入变量，工具默认官方源
# 用配置文件而非环境变量：npm/pip/uv/go 自动读取，不依赖 shell 环境加载
# flutter 的 pub/engine 下载走环境变量（PUB_HOSTED_URL/FLUTTER_STORAGE_BASE_URL，CLI 读取）；
#   注意与 mise 的 SDK 下载源（storage.googleapis.com 自定义 url）互不影响
# 说明：镜像配置对全平台统一生效（装过 node/go/uv/python/flutter 的机器自然受益，
#   未装对应组件的机器写文件也无副作用）

{ lib, useChinaMirror ? true, ... }:
{
  # ~/.npmrc：mise 装的 node 的 npm/pnpm/yarn 均读此文件
  # ~/.config/pip/pip.conf：pip 用户级配置（XDG 路径，https 源证书有效无需 trusted-host）
  # ~/.config/uv/uv.toml：uv 用户级配置（index-url 键自 uv 0.1 起均支持）
  # ~/.config/go/env：go env 持久化文件（go 自动读取，等价 go env -w）
  home.file = lib.mkIf useChinaMirror {
    ".npmrc".text = "registry=https://registry.npmmirror.com\n";
    ".config/pip/pip.conf".text = ''
      [global]
      index-url = https://pypi.tuna.tsinghua.edu.cn/simple
    '';
    ".config/uv/uv.toml".text = ''
      index-url = "https://pypi.tuna.tsinghua.edu.cn/simple"
    '';
    ".config/go/env".text = ''
      GOPROXY=https://goproxy.cn,direct
    '';
  };

  # flutter/dart pub 包与 engine 下载镜像（CLI 读环境变量，写 .zshenv 由 HM 注入所有 shell）
  home.sessionVariables = lib.mkIf useChinaMirror {
    PUB_HOSTED_URL = "https://pub.flutter-io.cn";
    FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn";
  };
}
