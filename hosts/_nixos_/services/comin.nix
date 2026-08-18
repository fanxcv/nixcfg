# comin：git 驱动的自动部署——服务器轮询仓库，检测到新 commit 自动 nixos-rebuild
# 适合无人值守的云服务器（Oracle 免费机等）；本地开发机建议手动 switch
# 前提：服务器能拉取仓库（公开仓库直连；私有仓库用带 token 的 URL 或 deploy key，
#   token 可放 agenix 加密文件里注入环境变量）
# 接入：flake.nix 注册 nixosConfigurations 时导入 hosts/_nixos_/base（见 hosts/README.md）

{
  lib,
  pkgs,
  ...
}:
let
  # comin 包共享构建（overlays/comin.nix，与 mini-m4 共用一份 buildGoModule，不再本地重复）
  comin = lib.getExe pkgs.comin;
  jq = lib.getExe' pkgs.jq "jq";
  sleep = lib.getExe' pkgs.coreutils "sleep";
  shuf = lib.getExe' pkgs.coreutils "shuf";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in
{
  services.comin = {
    enable = true;
    package = pkgs.comin;
    remotes = [
      {
        name = "origin";
        # 私有仓库认证：comin 用 go-git 库（不走 git credential.helper），
        # 必须显式配 username + access_token_path（token 由 agenix 解密，见 hosts/nix-pve/default.nix）
        url = "https://git.fan-x.fun/fan/nixcfg.git";
        auth = {
          username = "fan";
          access_token_path = "/run/agenix/comin-token";
        };
        branches.main.name = "main";
        # 轮询周期 180s（默认 60s；与 mini-m4 对齐，降低对 git 服务器打扰）
        poller.period = 180;
      }
    ];

    # 部署后若系统提示需要重启，延迟随机 30-300 秒再自动重启（避免多台同时重启）
    postDeploymentCommand = pkgs.writeShellScript "comin-reboot" ''
      if ${comin} status --json | ${jq} -e '.need_to_reboot' >/dev/null 2>&1; then
        if ! ${sleep} $(${shuf} -i 30-300 -n 1); then
          echo "Warning: sleep failed, proceeding to reboot anyway" >&2
        fi
        ${systemctl} reboot
      fi
    '';
  };
}
