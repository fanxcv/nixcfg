# ide 容器 mise 组件声明（共享；wanted.yaml 的 linux.ubuntu.ide-si/ide-lenovo.mise 维护）
#   组件清单从容器实测导出（mise ls --installed），纳入 nix 管理：
#     bun/go/java/maven/node/python/uv + 机器差异（lenovo：pipx + java oracle-17；si：java zulu-8）
#   激活时自动 mise install：config.toml 写入后安装缺失组件（幂等，已装版本秒级跳过）
#   容器内 /root/.config/mise 由宿主机 compose 挂载持久化（docker/ide/mise/config）
# config.toml 策略（→ _common_/mise/apply.py，实体文件可写）：
#   不存在 → nix 模板创建默认；已存在 → 补齐缺失键，已存在键保留用户版本；旧 symlink 自动实体化

{
  pkgs,
  lib,
  hostName,
  ...
}:
let
  # 机器差异：java 版本（si=zulu-8 / lenovo=oracle-17）
  java = if hostName == "ide-lenovo" then "oracle-17" else "zulu-8";
  # pipx 仅 lenovo 使用
  pipxLine = if hostName == "ide-lenovo" then "    pipx = \"latest\"\n" else "";
  configText = ''
    [tools]
    bun = "latest"
    go = "1.25"
    java = "${java}"
    maven = "3"
    node = "22"
    python = "3.12"
    uv = "latest"
  ''
  + pipxLine;
  template = pkgs.writeText "mise-config-${hostName}.toml" configText;
in
{
  # config.toml 默认模板/补齐（先于 mise install 执行）
  home.activation.setupMiseConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 ${./../_common_/mise/apply.py} \
      "$HOME/.config/mise/config.toml" "${template}"
  '';

  # config.toml 就绪后安装缺失组件（mise install 幂等；直接引用 store 路径，不依赖 PATH）
  home.activation.miseInstall = lib.hm.dag.entryAfter [ "setupMiseConfig" ] ''
    log=/tmp/mise-install.log
    if ${pkgs.mise}/bin/mise install --yes >"$log" 2>&1; then
      echo "===> mise install 完成（组件已就绪；日志 $log ）"
    else
      echo "警告: mise install 失败，见 $log"
      tail -20 "$log"
    fi
  '';
}
