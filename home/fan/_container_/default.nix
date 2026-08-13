# 容器平台层（_container_：Docker 容器等无独立系统平台的机器；当前：ide-si / ide-lenovo）
# 容器系统跑 Ubuntu → 继承 ../_ubuntu_（Ubuntu 平台基础包），再经它到 ../_linux_/ 与 ../_common_/
# 容器公共配置放这里（skemate.nix 等，机器目录只留专属微调）
# 模块自动扫描（tools.scan）：新增 .nix 文件即生效（当前：skemate.nix）

{ tools, ... }:
{
  imports = [ ../_ubuntu_ ] ++ tools.scan ./.;

  # standalone 入口（home/fan/default.nix）不参与内嵌模式，这里补 stateVersion
  home.stateVersion = "25.05";
}
