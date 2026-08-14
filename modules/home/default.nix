# home 层模块库（tsln 的 modules/home 思路）：跨平台用户级自定义模块（有 options 的扩展能力）
# 被 home/fan/_common_/default.nix 引用（所有平台含容器）；模块默认关闭，平台层按需启用
# 与 home/fan/_common_/ 的分工：模块库放可复用封装（options + 实现），_common_ 放具体配置
{ tools, ... }:
{
  imports = tools.scan ./.;
}
