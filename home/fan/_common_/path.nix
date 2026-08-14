# hm 激活环境 PATH 修复（全局统一，跨平台）
# hm 的 activate 脚本开头 set -eu + set -o pipefail，且 PATH 重置为纯 nix store
# （仅 bash/coreutils/diffutils/findutils/gettext/gnugrep/gnused/jq/ncurses/nix 十个包，
# 无任何系统工具）→ 裸命令（apt-get/systemctl/rc-service/journalctl/sudo/pkill/launchctl/
# python3）全部 command not found，set -e 直接中断激活（容器日志实证：libatomic1 失败 +
# sshd 重启失败 + "激活失败"三者同根因；另：诊断管道在 pipefail 下同样中断）
# 修复：writeBoundary 前置片段 export 系统 PATH——hm 的 activation 在同一脚本内顺序执行，
# export 全局保留，后续所有 activation 生效。各平台效果：
#   Ubuntu 容器/服务器 → /usr/bin（apt-get/systemctl）；NixOS → /run/current-system/sw/bin
#   （systemctl/sudo）；mac → /usr/bin（sudo/launchctl/pkill）；Alpine → /sbin（rc-service）
# 注意：nix 专属工具（python3/mise 等）不在这三个路径，仍需 ${pkgs.xxx} 绝对路径
#   （见 nix-pve/rustdesk.nix、_darwin_/rustdesk.nix、mini-m4/android-emulator.nix）
{ lib, ... }:
{
  home.activation.activatePathFix = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    export PATH="$PATH:/run/current-system/sw/bin:/usr/bin:/usr/sbin:/sbin:/bin"
  '';
}
