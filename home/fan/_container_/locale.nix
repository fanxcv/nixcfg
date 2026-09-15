# 容器系统 locale：en_US.UTF-8 / zh_CN.UTF-8（ide-si / ide-lenovo 共用）
#
# 问题：Ubuntu 基础镜像只有 C / C.UTF-8 / POSIX（无 locales 包、无 /usr/share/i18n 源）。
#   客户端（mac 的 nix-darwin 环境 = en_US.UTF-8，ssh 默认 SendEnv LANG LC_*，sshd 默认 AcceptEnv LANG LC_*）
#   把 LC_ALL/LANG 带进容器 → setlocale 失败：
#     bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
#   且缺 locale 时回退 C，Python/Java 默认编码退化为 ASCII（非 ASCII 读写报错）。
#
# 修法：容器自带 glibc 的 localedef（/usr/bin/localedef，来自 libc-bin）+ nix glibc 的 i18n 源数据，
#   写进**系统** locale-archive（/usr/lib/locale/locale-archive）——所有进程（含系统 bash、sshd 会话、
#   docker exec）直接可见；不用 LOCPATH（nix 专属环境变量，只对 nix 二进制生效），也不动
#   ide-lenovo/kasmvnc.nix 的 GUI 会话 LOCPATH。
#   版本关系：i18n 源是文本，由容器 glibc（Ubuntu 24.04 = 2.39）的 localedef 编译 → 产物与系统 glibc 同源。
#
# 幂等：locale -a 命中即跳过；容器重建后 /usr/lib/locale 清空，auto-deploy 首轮激活自动重建（见 ide-auto-deploy.sh）。

{ pkgs, lib, ... }:
{
  home.activation.containerLocale = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x /usr/bin/localedef ]; then
      echo "警告: /usr/bin/localedef 缺失（libc-bin），容器 locale 未生成"
    else
      for name in en_US zh_CN; do
        if /usr/bin/locale -a | grep -qix "$name.utf8"; then
          continue
        fi
        if I18NPATH=${pkgs.glibc}/share/i18n /usr/bin/localedef -i "$name" -f UTF-8 "$name.UTF-8"; then
          echo "===> locale $name.UTF-8 已生成（系统 locale-archive）"
        else
          echo "警告: locale $name.UTF-8 生成失败（localedef）"
        fi
      done
    fi
  '';
}
