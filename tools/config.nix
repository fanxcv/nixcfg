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
}