# 容器平台层工具包（ide-si / ide-lenovo 共用）
#   http-server：npm 全局包改 nix 管理（history 高频使用：本地静态服务器）
#   unzip / git-lfs：原容器内手工 apt 安装，改 nix 包
#   libatomic1：GCC runtime 库，nixpkgs 无对应包（apt 专属），激活脚本按 maven 组件
#     是否声明决定安装（mise config.toml 有 maven 才装；dpkg 判断幂等）

{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    http-server
    unzip
    git-lfs
  ];

  home.activation.setupContainerApt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # libatomic1 关联 maven：config.toml（../mise.nix 声明，激活顺序 writeBoundary 之后已就位）有 maven 才装
    if grep -q '^maven' /root/.config/mise/config.toml 2>/dev/null; then
      if ! dpkg -s libatomic1 >/dev/null 2>&1; then
        APT_LOG=/tmp/container-apt.log
        apt-get update -qq >"$APT_LOG" 2>&1 || true
        if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libatomic1 >>"$APT_LOG" 2>&1; then
          echo "[container-apt] libatomic1 已安装（maven 依赖）"
        else
          echo "警告: libatomic1 安装失败（下次激活重试；日志 /tmp/container-apt.log，尾部）："
          tail -n 6 "$APT_LOG" 2>/dev/null | sed 's/^/  /'
        fi
      fi
    fi
  '';
}
