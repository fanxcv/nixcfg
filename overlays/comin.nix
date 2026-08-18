# comin 包共享构建 overlay（消除 hosts/_nixos_/services/comin.nix 与 hosts/mini-m4/comin.nix 两处逐字重复）
# nixpkgs 稳定版（26.05）无此包，用 comin input 源码重写构建
#   - overrideModAttrs 注入 GOPROXY=goproxy.cn：Go 依赖下载默认走 proxy.golang.org（国内被墙），
#     goModules 是 buildGoModule 内部独立 FOD，只能在构造时注入（installer/rebuild/comin 全链路生效）
#   - wrapProgram 挂 GIT_CONFIG_SYSTEM + git：comin 运行时 go-git 需要 git 与 safe.directory 配置
# 引用：hosts/_nixos_/services/comin.nix（官方 services.comin 模块）、hosts/mini-m4/comin.nix（自管理 LaunchDaemon）
{ lib, inputs }:
final: prev: {
  comin = final.buildGoModule {
    pname = "comin";
    version = "0.14.0";
    src = inputs.comin;
    vendorHash = "sha256-M+0YUoMRnObCSUqnygPNiv1sKl3YB9Cb4nzK39zWwBg=";
    ldflags = [ "-X github.com/nlewo/comin/cmd.version=0.14.0" ];
    meta.mainProgram = "comin"; # 消除 getExe 的 deprecated warning
    nativeCheckInputs = [ final.git ];
    doCheck = false;
    overrideModAttrs = _: prev: {
      # GOPROXY 在 goModules 的 impureEnvVars 列表（daemon 环境无此变量时会覆盖清空 env 注入），
      # 只能在构建脚本里 export（preBuild 在 go mod vendor 前执行）
      preBuild = ''
        export GOPROXY=https://goproxy.cn,direct
      '';
    };
    nativeBuildInputs = [ final.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/comin --set GIT_CONFIG_SYSTEM ${final.writeText "git.config" ''
        [safe]
           directory = *
        [core]
           hooksPath = /dev/null
      ''} --prefix PATH : ${lib.makeBinPath [ final.git ]}
    '';
  };
}
