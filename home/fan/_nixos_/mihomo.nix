# mihomo（Clash Meta 内核）声明式安装 + 订阅配置生成（所有 NixOS 真机：nix-lenovo / nix-book / nix-asus）
# 订阅：与 macOS ClashX Meta 同一地址（见 home/fan/_darwin_/gui/apps/clashx-meta.nix）；URL 含凭据，经 age 加密托管
# 配置：订阅为基，仓库内 mihomo/base.yaml（仅非敏感设置项，随部署进 store，不落 home）覆盖
#       proxies/proxy-groups/rules 之外的键；mode/UI/DNS 端口三处修正见 mihomo/apply.py 头部说明
# 服务：用户级 systemd（以 fan 身份读 home 配置）；linger 在 hosts/_nixos_/base 开启（开机即启，不等登录）
# 订阅更新：mihomo-refresh.service 开机重取 ＋ mihomo-refresh.timer 每日定时重取
#   （激活期只跑一次，重启机器不会重拉；节点会过期/失效，故必须有开机与定时刷新）
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

  # 订阅刷新（开机 + 每日）：激活期只生成一次，重启不重拉，节点过期后代理失效 →
  # 本服务先拉新订阅写配置，再重启内核使其生效
  # 为何不拆两个 unit、也不用 ExecStartPost/ExecStopPost：
  #   实测（systemd 替身 unit 对照）ExecStartPost / ExecStopPost 属于 unit 的控制进程链，
  #   在其中调 systemctl 会破坏 systemd 对该 unit 的作业管理 → 发起方与被操作方均失败；
  #   而**独立 ExecStart 里经 sh -c 调 systemctl 可行**（实测 zz-b=success 且目标 PID 变更、
  #   双方均 active），故沿用单 unit 两段式
  systemd.user.services.mihomo-refresh = {
    Unit = {
      Description = "mihomo 订阅刷新（重取订阅 + 合并模板 + 重启内核）";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      # apply.py 内置重试与失败容忍（订阅拉取失败仅警告并保留现有配置）
      # 重启在 apply.py 成功后执行；用 restart 而非 external-controller 热重载：
      #   实测启动竞态下 9090 可能未监听（bind 失败被静默跳过），热重载不可靠；
      #   刷新在开机后 1min 跑，此时无长连接，重启代价可忽略
      # 二进制路径：NixOS 无 /usr/bin/systemctl，systemd 在 current-system 下
      ExecStart = "/bin/sh -c '${python}/bin/python3 ${./mihomo/apply.py} \"${subUrlFile}\" \"${baseYaml}\" \"${zashboardUi}\" \"${mihomoConfig}\" && /run/current-system/sw/bin/systemctl --user restart mihomo.service'";
    };
  };

  # 开机后 1 分钟刷新一次（等网络就绪），之后每日 04:17 刷新（避开整点拥挤）
  systemd.user.timers.mihomo-refresh = {
    Unit.Description = "mihomo 订阅定时刷新";
    Timer = {
      OnBootSec = "1min";
      OnCalendar = "*-*-* 04:17:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

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
