# comin：git 驱动自动部署（mini-m4 实验机）
#   触发：root LaunchDaemon（comin darwin 模块，KeepAlive+RunAtLoad），默认 60s 轮询 git.fan-x.fun
#   逻辑：comin 检测 darwinConfigurations.mini-m4 变更 → 自动 build + activate（root 直跑，免 sudo，
#     与手动 `nix run .#mini-m4` 等价但由 launchd 无人值守触发）
#   包：nixpkgs 26.05 无 comin → 用 input 源码重写构建（同 hosts/_nixos_/services/comin.nix；
#     实验成功后考虑提取共享，当前内联避免动 nix-pve）
#   认证：comin 用 go-git 库不走 git credential.helper → 必须显式 access_token_path
#     （agenix 解密 secrets/comin-token.age → /run/agenix/comin-token，fan 域 age 私钥可解）
#   状态/日志：/var/lib/comin（仓库 clone + 部署状态）、/var/log/comin.log
#   注：comin 自持 clone（/var/lib/comin），不复用 ~/nixcfg——手动改完必须 push 才生效
{
  lib,
  pkgs,
  inputs,
  tools,
  ...
}:
let
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
in
{
  imports = [ inputs.comin.darwinModules.comin ];

  # comin 拉取私有仓库的 token（go-git 认证，非 credential.helper）
  age.secrets."comin-token" = {
    file = tools.relative "secrets/comin-token.age";
    path = "/run/agenix/comin-token";
    mode = "0400";
  };

  services.comin = {
    enable = true;
    package = cominPkg;
    remotes = [
      {
        name = "origin";
        # 私有仓库认证：go-git 不走 credential.helper，显式 username + access_token_path
        url = "https://git.fan-x.fun/fan/nixcfg.git";
        auth = {
          username = "fan";
          access_token_path = "/run/agenix/comin-token";
        };
        branches.main.name = "main";
      }
    ];
  };
}
