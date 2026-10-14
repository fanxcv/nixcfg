# mihomo（Clash Meta 内核）声明式安装 + 订阅配置生成（nix-pve / nix-lenovo 共享）
# 订阅：与 macOS ClashX Meta 同一地址（见 home/fan/_darwin_/gui/apps/clashx-meta.nix）；URL 含凭据，经 age 加密托管
# 配置：订阅为基，仓库内 mihomo/base.yaml（仅非敏感设置项，随部署进 store，不落 home）覆盖
#       proxies/proxy-groups/rules 之外的键；mode/UI/DNS 端口三处修正见 mihomo/apply.py 头部说明
# 服务：用户级 systemd（以 fan 身份读 home 配置）；linger 在 hosts/_nixos_/base 开启（开机即启，不等登录）
# UI：zashboard（固定版本 + hash，构建期下载），external-ui 指向只读 store 路径；
#     1.19.x 起内核限制配置内路径必须在 home（-d 目录）或 SAFE_PATHS 内，故经 SAFE_PATHS 放行该 store 路径
# 注：mihomo/ 子目录无 default.nix，tools.scan 会跳过它（脚本由本文件显式引用）
{
  pkgs,
  lib,
  config,
  tools,
  self,
  ...
}:
let
  cfg = tools.config;
  # 升级 UI：改版本号 + 重新取 hash（nix hash file dist.zip），与 ClashX Meta 同款手动升级模式
  zashboardVersion = "3.29.1";
  zashboardUrl = "https://github.com/Zephyruso/zashboard/releases/download/v${zashboardVersion}/dist.zip";
  zashboardSrc =
    if cfg.useChinaMirror && cfg.githubProxy != "" then
      cfg.githubProxy + zashboardUrl
    else
      zashboardUrl;
  # fetchzip 剥掉 zip 顶层 dist/，$out 即 UI 根目录（hash 为解压后 NAR，非 zip 文件）
  zashboardUi = pkgs.fetchzip {
    url = zashboardSrc;
    hash = "sha256-Ibo2iB/U3JLFAj8w4ukKau/W35sBPpJjdcP1Atnv/2U=";
  };
  homeDir = config.home.homeDirectory;
  # 订阅地址含凭据（与 macOS 端同一地址）：age 加密托管，激活期解密到 $HOME/.secrets 再读
  subUrlFile = "${homeDir}/.secrets/clash-sub-url";
  mihomoDir = "${homeDir}/.config/mihomo";
  mihomoConfig = "${mihomoDir}/config.yaml";
  baseYaml = ./mihomo/base.yaml;
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in
{
  home.activation.setupMihomo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (umask 077; ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o "${subUrlFile}" ${self}/secrets/clash-sub-url.age)
    ${python}/bin/python3 ${./mihomo/apply.py} \
      "${subUrlFile}" "${baseYaml}" "${zashboardUi}" "${mihomoConfig}"
  '';

  systemd.user.services.mihomo = {
    Unit = {
      Description = "mihomo (Clash Meta) proxy";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${mihomoDir}";
      # external-ui 在只读 store，需经 SAFE_PATHS 白名单（否则内核报 path is not subpath of home directory）
      Environment = [ "SAFE_PATHS=${zashboardUi}" ];
      # mode=global 的出口由 GLOBAL 组决定，启动后指向延迟择优组
      ExecStartPost = "${python}/bin/python3 ${./mihomo/select-global.py} ${mihomoConfig}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
