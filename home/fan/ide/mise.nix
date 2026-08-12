# ide 容器 mise 组件声明（wanted.yaml 的 linux.ide.mise 维护，按容器区分）
#   组件清单从容器实测导出（mise ls --installed），纳入 nix 管理：
#     si-11:  bun/go/java(zulu-8)/maven/node/python/uv
#     lenovo: 上述 + pipx，java 默认 oracle-17
#   激活时自动 mise install：config.toml 写入后安装缺失组件（幂等，已装版本秒级跳过）
#   未指定 ideMachine（兜底，当前所有入口 .#ide-si11 / .#ide-lenovo 均已指定）→ 不接管 config.toml，保持手配
#   容器内 /root/.config/mise 由宿主机 compose 挂载持久化（docker/ide/mise/config）

{ pkgs, lib, ideMachine ? null, ... }:
let
  common = ''
    [tools]
    bun = "latest"
    go = "1.25"
    maven = "3"
    node = "22"
    python = "3.12"
    uv = "latest"
  '';
  extra =
    if ideMachine == "lenovo" then ''
      java = "oracle-17"
      pipx = "latest"
    '' else if ideMachine == "si11" then ''
      java = "zulu-8"
    '' else null;
in
{
  home.file.".config/mise/config.toml" = lib.mkIf (extra != null) {
    text = common + extra;
  };

  # config.toml 写入后自动安装缺失组件（mise install 幂等；直接引用 store 路径，不依赖 PATH）
  home.activation.miseInstall = lib.mkIf (extra != null) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    log=/tmp/mise-install.log
    if ${pkgs.mise}/bin/mise install --yes >"$log" 2>&1; then
      echo "===> mise install 完成（组件已就绪；日志 $log）"
    else
      echo "警告: mise install 失败，见 $log"
      tail -20 "$log"
    fi
  '');
}
