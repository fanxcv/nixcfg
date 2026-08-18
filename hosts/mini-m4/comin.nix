# comin：git 驱动自动部署（mini-m4 实验机）
#   触发：root LaunchDaemon（KeepAlive+RunAtLoad），poller 180s 轮询 git.fan-x.fun
#   逻辑：comin 检测 darwinConfigurations.mini-m4 变更 → 自动 build + activate（root 直跑，免 sudo）
#   包：nixpkgs 26.05 无 comin → 用 input 源码重写构建（同 hosts/_nixos_/services/comin.nix）
#   认证：comin 用 go-git 库不走 git credential.helper → 显式 access_token_path
#     （agenix 解密 secrets/comin-token.age → /run/agenix/comin-token）
#   状态/日志：/var/lib/comin（仓库 clone + 部署状态）、/var/log/comin.log
#   注：comin 自持 clone（/var/lib/comin），不复用 ~/nixcfg——手动改完必须 push 才生效
#
#   ★ 自管理 LaunchDaemon（2026-08-18 死锁事故后改为自管理，不再用 comin 官方 darwin 模块的
#     launchd.daemons）：comin 自身触发部署时 activate 的 launchd service setup 会 reload 所有
#     launchd.daemons 服务 → comin 在跑 activate 又被要求退出 → 死锁（激活卡在 reloading comin）。
#     改由 activationScripts 直接 install plist + bootstrap：activate 不再重载 comin（不在
#     launchd.daemons 列表），activation 内也检测运行态幂等不动。comin 自身生命周期由 KeepAlive
#     管理（部署成功后 comin 主动 exit 让 launchd 重启读新配置）。

{
  lib,
  pkgs,
  config,
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
    meta.mainProgram = "comin"; # 消除 getExe 的 deprecated warning
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

  # comin 运行配置（对应 comin v0.14.0 生成的 comin.yaml 全量；手动维护避免依赖官方 darwin 模块）
  cominYaml = pkgs.writeText "comin.yaml" ''
    hostname: mini-m4
    state_dir: /var/lib/comin
    repository_type: flake
    repository_subdir: .
    submodules: false
    eval_timeout: 1800
    build_timeout: 1800
    remotes:
    - name: origin
      url: https://git.fan-x.fun/fan/nixcfg.git
      auth:
        username: fan
        access_token_path: /run/agenix/comin-token
      branches:
        main:
          name: main
          operation: switch
      poller:
        period: 180
      timeout: 300
    retention:
      deployment_any_capacity: 5
      deployment_boot_entry_capacity: 3
      deployment_successful_capacity: 3
    build_confirmer:
      mode: without
      autoconfirm_duration: 120
    deploy_confirmer:
      mode: without
      autoconfirm_duration: 120
    exporter:
      port: 4243
    gpg_public_key_paths: []
    system_attr: null
  '';

  # root LaunchDaemon（自管理，不进 nix-darwin launchd.daemons，见文件头注释）
  cominPlist = pkgs.writeText "com.github.nlewo.comin.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>com.github.nlewo.comin</string>
      <key>ProgramArguments</key>
      <array>
        <string>${cominPkg}/bin/comin</string>
        <string>run</string>
        <string>--config</string>
        <string>${cominYaml}</string>
      </array>
      <key>KeepAlive</key>
      <true/>
      <key>RunAtLoad</key>
      <true/>
      <key>StandardErrorPath</key>
      <string>/var/log/comin.log</string>
      <key>StandardOutPath</key>
      <string>/var/log/comin.log</string>
      <key>EnvironmentVariables</key>
      <dict>
        <key>PATH</key>
        <string>${lib.makeBinPath [ config.nix.package pkgs.git pkgs.openssh ]}</string>
      </dict>
    </dict>
    </plist>
  '';
in
{
  # import comin 模块以提供 services.comin.machineId 属性（comin eval 必读，缺失则新 commit 永不被部署）。
  # enable 保持默认 false：官方 launchd.daemons 不启用，自管理 plist 不受影响，仅借用 options 定义。
  imports = [ inputs.comin.darwinModules.comin ];

  # comin 拉取私有仓库的 token（go-git 认证，非 credential.helper）
  age.secrets."comin-token" = {
    file = tools.relative "secrets/comin-token.age";
    path = "/run/agenix/comin-token";
    mode = "0400";
  };

  # 自管理安装 comin LaunchDaemon：
  #   - 已运行则只覆盖 plist 文件不动进程（避免激活干扰 comin 部署，comin 自己 KeepAlive 重启）
  #   - 未运行（首次安装/事故恢复）则 bootstrap 拉起
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    install -m 0644 ${cominPlist} /Library/LaunchDaemons/com.github.nlewo.comin.plist
    if ! /bin/launchctl print system/com.github.nlewo.comin >/dev/null 2>&1; then
      /bin/launchctl bootstrap system /Library/LaunchDaemons/com.github.nlewo.comin.plist 2>/dev/null \
        || echo "警告: comin bootstrap 失败（下次激活重试或手动 sudo launchctl bootstrap system /Library/LaunchDaemons/com.github.nlewo.comin.plist）"
    fi
  '';
}
