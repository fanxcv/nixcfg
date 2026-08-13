# ide-lenovo 容器 mise 组件声明（wanted.yaml 的 linux.ubuntu.ide-lenovo.mise 维护）
#   组件清单从容器实测导出（mise ls --installed），纳入 nix 管理：
#     si 相同组件 + pipx，java 默认 oracle-17（si 为 zulu-8，见 ../ide-si/mise.nix）
#   激活时自动 mise install：config.toml 写入后安装缺失组件（幂等，已装版本秒级跳过）
#   容器内 /root/.config/mise 由宿主机 compose 挂载持久化

{ pkgs, lib, ... }:
let
  configText = ''
    [tools]
    bun = "latest"
    go = "1.25"
    java = "oracle-17"
    maven = "3"
    node = "22"
    python = "3.12"
    uv = "latest"
    pipx = "latest"
  '';
in
{
  home.file.".config/mise/config.toml" = {
    text = configText;
  };

  # config.toml 写入后自动安装缺失组件（mise install 幂等；直接引用 store 路径，不依赖 PATH）
  home.activation.miseInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    log=/tmp/mise-install.log
    if ${pkgs.mise}/bin/mise install --yes >"$log" 2>&1; then
      echo "===> mise install 完成（组件已就绪；日志 $log）"
    else
      echo "警告: mise install 失败，见 $log"
      tail -20 "$log"
    fi
  '';
}
