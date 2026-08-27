# 全局镜像/代理集中配置（唯一配置入口 —— 改国内镜像开关 / GitHub 加速域名只动这一个文件）
# 被 tools/default.nix 读入并以 tools.config 注入所有模块（specialArgs.tools），
#   模块不再各自写默认值；flake.nix 注入的 useChinaMirror 默认值也来自这里（机器级可覆盖）。
# 注意：flake inputs 的 GitHub 前缀是 url 字面量（flake 解析器限制，读不了这里），
#   由 scripts/switch-github-proxy.sh 以本文件 githubProxy 为准同步替换 flake.nix / flake.lock。
{
  # 是否走国内镜像（false = 国外直连场景，工具/下载用官方源）
  useChinaMirror = true;

  # GitHub 加速前缀（完整 https 前缀、尾部斜杠；留空 = 直连 GitHub）
  githubProxy = "https://ghfast.top/";

  # 不走代理的 URL 例外（前缀或精确 URL，命中则直连原地址、不套 githubProxy）
  # 例：ghfast 不支持 GitHub 用户 keys 端点（github.com/<user>.keys），fanxcv 公钥拉取必须直连
  withoutProxy = [
    "https://github.com/fanxcv.keys"
  ];

  # Nix 二进制缓存（Nix 模块直接读取；flake.nix/Dockerfile/PVE shell 属解析边界，手写对齐）
  nixSubstituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];
  nixCachixSubstituters = [
    "https://cache.numtide.com"
    "https://nix-community.cachix.org"
  ];
  nixCachixTrustedPublicKeys = [
    "cache.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  # Docker/Podman/OrbStack registry mirrors（Nix 模块直接读取；pve/apply.sh 静态块手写对齐）
  dockerRegistryMirrors = [
    "https://docker.xuanyuan.me"
    "https://docker.1ms.run"
    "https://docker.m.daocloud.io"
  ];

  # RustDesk 自建 hbbs/hbbr（客户端注入统一由 tools/rustdesk-inject.py 实现）
  rustdesk = {
    server = "120.55.164.147:21116";
    relay = "120.55.164.147";
    key = "biYiu92uX5k0qOaDuhLIpVRcD0iYwqAOlSCDCR14uHg=";
    # GUI 解锁安全设置的 PIN（→ injector --pin；bwrap 沙箱内 sudo 必败，PIN 是唯一解锁通道）。
    # 明文入库：属本地解锁凭据（解锁后仅能改本机 ID/密码/权限），不影响远程访问安全。
    unlockPin = "246810";
  };
}
