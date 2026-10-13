# comin：git 驱动的自动部署——服务器轮询仓库，检测到新 commit 自动 nixos-rebuild
# 归属：nix-pve 独有（hosts/nix-pve/services/，由 tools.scan 自动导入；
#   模块本身由 hosts/nix-pve/default.nix 显式 import inputs.comin.nixosModules.comin）
# 其余机器不启用：nix-lenovo 笔记本与 macOS 手动 nixos-rebuild / nix run
# 前提：能拉取私有仓库——go-git 不走 git credential.helper，用 agenix 注入的 access token
#   （声明见 hosts/nix-pve/default.nix）

{
  lib,
  pkgs,
  ...
}:
let
  # comin 包构建（overlays/comin.nix，nixpkgs 稳定版 26.05 无此包）
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
        # 只自动部署 main：test 等分支一律手动（nixos-rebuild switch --flake .#nix-pve）。
        # 空 testing 名 = comin 跳过 testing 分支（repository.go: if remote.Testing.Name == "" { continue }），
        # 否则默认 testing-<hostname> 会被轮询并自动 test 部署
        branches.testing.name = "";
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
