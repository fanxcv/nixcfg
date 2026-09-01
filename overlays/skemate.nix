# skemate（自研终端复用服务）分发 overlay
# 二进制从 skemate 仓库 flake output 取（flake.lock 锁定 rev，纯 eval 无 --impure）：
#   skemate 仓库（hc-git.qksxin.com/wangyu/skemate）flake.nix 读仓库内提交的 latest.json
#   （version/url/sha256 发版快照，builtins.readFile 纯操作）→ packages.<system>.skemate 直接 cp 二进制
#   → nixcfg 升级 = nix flake update skemate（锁 deploy 分支 rev，见 flake.nix inputs.skemate）
#   发版流程（skemate 仓库，deploy 分支）：make release → 版本化目录推 CDN + 更新仓库内 latest.json → push deploy
# 历史：早期【build 期】curl latest.json（version 恒 "unstable"，drv 不变假自动）；
#       中期【eval 期】fetchurl 无 hash 拉 w-apis.qksxin.com/terminal/latest.json（--impure，
#       每次 eval 联网；API 源站 latest.json 走 API 缓存易不更新）；
#       现改 flake.lock 锁定 git rev（正解）。
# 平台：skemate 仓库 flake 只发 x86_64-linux / aarch64-darwin / aarch64-linux，其余平台直接构建失败并提示
inputs: final: prev:
let
  system = final.stdenv.hostPlatform.system;
in
{
  # 取 skemate 仓库 flake 的 packages.<system>.skemate（二进制 eval 期 fetchurl 带 sha256 内容寻址，
  # store 复用不重复下载；构建期纯 cp 零网络）
  skemate =
    if builtins.elem system [
      "x86_64-linux"
      "aarch64-darwin"
      "aarch64-linux"
    ]
    then inputs.skemate.packages.${system}.skemate
    else throw "skemate: 平台 ${system} 无官方构建（skemate flake 只发 x86_64-linux / aarch64-darwin / aarch64-linux）";
}
