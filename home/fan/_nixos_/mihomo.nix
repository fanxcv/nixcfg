# mihomo（Clash Meta 内核）声明式安装 + 订阅配置生成（nix-pve / nix-lenovo 共享）
# 订阅：与 macOS ClashX Meta 同一地址（见 home/fan/_darwin_/gui/apps/clashx-meta.nix）
# 配置：订阅为基，本地偏好 ~/config.yaml 覆盖 proxies/proxy-groups/rules 之外的键；
#       mode/UI/DNS 端口三处修正见 mihomo/apply.py 头部说明
# 服务：用户级 systemd（以 fan 身份读 home 配置）；linger 在 hosts/_nixos_/base 开启（开机即启，不等登录）
# UI：zashboard（固定版本 + hash，构建期下载），external-ui 指向只读 store 路径，内核不再自行下载
# 注：mihomo/ 子目录无 default.nix，tools.scan 会跳过它（脚本由本文件显式引用）
{
  pkgs,
  lib,
  config,
  tools,
  ...
}:
let
  cfg = tools.config;
  # 升级 UI：改版本号 + 重新取 hash（nix hash file dist.zip），与 ClashX Meta 同款手动升级模式
  zashboardVersion = "3.29.1";
  zashboardUrl = "https://github.com/Zephyruso/zashboard/releases/download/v${zashboardVersion}/dist.zip";
  zashboardSrc =
    if cfg.useChinaMirror && cfg.githubProxy != "" then cfg.githubProxy + zashboardUrl else zashboardUrl;
  # fetchzip 剥掉 zip 顶层 dist/，$out 即 UI 根目录（hash 为解压后 NAR，非 zip 文件）
  zashboardUi = pkgs.fetchzip {
    url = zashboardSrc;
    hash = "sha256-Ibo2iB/U3JLFAj8w4ukKau/W35sBPpJjdcP1Atnv/2U=";
  };
  # 订阅地址（token 含凭据，不入 store，仅运行时下载）与 macOS 端保持一致
  subUrl = "https://xx.fan-x.eu.org/api/v1/client/subscribe?token=eaa63ab248c016278df7f8f6d2847757";
  homeDir = config.home.homeDirectory;
  mihomoDir = "${homeDir}/.config/mihomo";
  mihomoConfig = "${mihomoDir}/config.yaml";
  localYaml = "${homeDir}/config.yaml";
  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
in
{
  home.activation.setupMihomo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${python}/bin/python3 ${./mihomo/apply.py} \
      "${subUrl}" "${localYaml}" "${zashboardUi}" "${mihomoConfig}"
  '';

  systemd.user.services.mihomo = {
    Unit = {
      Description = "mihomo (Clash Meta) proxy";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.mihomo}/bin/mihomo -d ${mihomoDir}";
      # mode=global 的出口由 GLOBAL 组决定，启动后指向延迟择优组
      ExecStartPost = "${python}/bin/python3 ${./mihomo/select-global.py} ${mihomoConfig}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
