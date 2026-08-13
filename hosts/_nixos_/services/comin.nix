# comin：git 驱动的自动部署——服务器轮询仓库，检测到新 commit 自动 nixos-rebuild
# 适合无人值守的云服务器（Oracle 免费机等）；本地开发机建议手动 switch
# 前提：服务器能拉取仓库（公开仓库直连；私有仓库用带 token 的 URL 或 deploy key，
#   token 可放 agenix 加密文件里注入环境变量）
# 接入：flake.nix 注册 nixosConfigurations 时导入 hosts/_nixos_/base（见 hosts/README.md）

{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  # comin 包：nixpkgs 稳定版（26.05）无此包，用 comin input 源码重写构建
  #   - overrideModAttrs 注入 GOPROXY=goproxy.cn：Go 依赖下载默认走 proxy.golang.org（国内被墙），
  #     goModules 是 buildGoModule 内部独立 FOD，只能在构造时注入（installer/rebuild/comin 全链路生效）
  #   - wrapProgram 挂 GIT_CONFIG_SYSTEM + git：comin 运行时 go-git 需要 git 与 safe.directory 配置
  cominPkg = pkgs.buildGoModule {
    pname = "comin";
    version = "0.14.0";
    src = inputs.comin;
    vendorHash = "sha256-M+0YUoMRnObCSUqnygPNiv1sKl3YB9Cb4nzK39zWwBg=";
    ldflags = [ "-X github.com/nlewo/comin/cmd.version=0.14.0" ];
    nativeCheckInputs = [ pkgs.git ];
    doCheck = false;
    overrideModAttrs = _: prev: {
      # GOPROXY 在 goModules 的 impureEnvVars 列表（daemon 环境无此变量时会覆盖清空 env 注入），
      # 只能在构建脚本里 export（preBuild 在 go mod vendor 前执行）
      preBuild = ''
        export GOPROXY=https://goproxy.cn,direct
      '';
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/comin --set GIT_CONFIG_SYSTEM ${pkgs.writeText "git.config" ''
        [safe]
           directory = *
        [core]
           hooksPath = /dev/null
      ''} --prefix PATH : ${lib.makeBinPath [ pkgs.git ]}
    '';
  };
  comin = lib.getExe config.services.comin.package;
  jq = lib.getExe' pkgs.jq "jq";
  sleep = lib.getExe' pkgs.coreutils "sleep";
  shuf = lib.getExe' pkgs.coreutils "shuf";
  systemctl = lib.getExe' pkgs.systemd "systemctl";
in
{
  services.comin = {
    enable = true;
    package = cominPkg;
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
