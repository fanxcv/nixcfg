# ide-si 容器系统环境接管：环境变量 + 外部 hosts —— 替代 docker-compose 的 environment / extra_hosts
# 背景：compose 注入的变量/hosts 修改必须重建容器；nix 激活直接写入，免重建，nix run 即生效
# 通道（全覆盖）：
#   systemd 系统服务 → /etc/environment.d/*.conf（新启动服务生效；已运行服务 restart 后生效）
#   shell            → home.sessionVariables（.zshenv）
#   SSH 会话         → ~/.ssh/environment（PermitUserEnvironment，sshd 无需重启，覆盖同名变量）
#   JVM 进程         → JAVA_TOOL_OPTIONS（tb-cli 等 JVM 不读 shell 代理，注入 JVM 系统属性）
#   hosts            → activation 幂等追加 + systemd oneshot 启动自动恢复（容器重启 Docker 重写 /etc/hosts）
# 过渡期：compose 同值保留双保险；改值只改这里；稳定后可从 compose 移除
# 范围：本机（ide-si）代理 + 内网 hosts；lenovo 国内直连无此配置（见 ../ide-lenovo/）

{ pkgs, lib, ... }:
let
  # 代理：与 docker-compose-si.yml 一致；NO_PROXY 含内网 CIDR（JVM 版见 JAVA_TOOL_OPTIONS）
  proxyHost = "pve.mi.fan-x.eu.org";
  proxyPort = "7890";
  proxyUrl = "http://${proxyHost}:${proxyPort}";
  noProxy = "127.0.0.1,localhost,::1,10.*,10.0.0.0/8,172.*,172.0.0.0/8,.qksxin.com";
  # JVM nonProxyHosts 用 | 分隔通配（不支持 CIDR），对齐 NO_PROXY
  jvmNonProxyHosts = "localhost|127.*|[::1]|10.*|172.*|*.qksxin.com";
  javaToolOptions = "-Dhttp.proxyHost=${proxyHost} -Dhttp.proxyPort=${proxyPort} -Dhttps.proxyHost=${proxyHost} -Dhttps.proxyPort=${proxyPort} -Dhttp.nonProxyHosts=${jvmNonProxyHosts}";

  # 环境变量清单（KEY=value，同时写入 environment.d 与 ~/.ssh/environment）
  envLines = [
    "all_proxy=${proxyUrl}"
    "ALL_PROXY=${proxyUrl}"
    "http_proxy=${proxyUrl}"
    "HTTP_PROXY=${proxyUrl}"
    "https_proxy=${proxyUrl}"
    "HTTPS_PROXY=${proxyUrl}"
    "no_proxy=${noProxy}"
    "NO_PROXY=${noProxy}"
    "JAVA_TOOL_OPTIONS=${javaToolOptions}"
  ];
  envText = lib.concatStringsSep "\n" envLines + "\n";

  # 外部 hosts（compose extra_hosts 同款：IP 域名）
  hostLines = [
    "10.1.0.30 gitlab.hczqdev.cn"
    "10.1.0.30 maven.hzdev.cn"
  ];

  # 幂等追加脚本：激活即跑 + oneshot 服务容器启动自动恢复
  hostsScript = pkgs.writeShellScript "ide-extra-hosts" ''
    set -eu
    ${lib.concatMapStringsSep "\n" (line: "grep -qxF '${line}' /etc/hosts || echo '${line}' >> /etc/hosts") hostLines}
  '';

  hostsUnit = ''
    [Unit]
    Description=Append ide extra hosts entries
    After=systemd-remount-fs.service
    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=@hostsScript@
    [Install]
    WantedBy=multi-user.target
  '';
in
{
  # shell 通道（zsh 全实例读 .zshenv → hm-session-vars.sh）
  home.sessionVariables = {
    all_proxy = proxyUrl;
    ALL_PROXY = proxyUrl;
    http_proxy = proxyUrl;
    HTTP_PROXY = proxyUrl;
    https_proxy = proxyUrl;
    HTTPS_PROXY = proxyUrl;
    no_proxy = noProxy;
    NO_PROXY = noProxy;
    JAVA_TOOL_OPTIONS = javaToolOptions;
  };

  home.activation.ideSysEnv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # 1) systemd 系统服务环境（新启动服务生效；已运行服务 restart 后生效）
    envd=/etc/environment.d/zz-ide-proxy.conf
    mkdir -p /etc/environment.d
    tmp=$(mktemp)
    printf '%s' '${envText}' > "$tmp"
    if ! cmp -s "$tmp" "$envd" 2>/dev/null; then
      cp "$tmp" "$envd"
    fi
    rm -f "$tmp"

    # 2) SSH 会话环境（PermitUserEnvironment：sshd 无需重启，新会话即注入且覆盖同名变量）
    mkdir -p /root/.ssh
    envfile=/root/.ssh/environment
    tmp=$(mktemp)
    printf '%s' '${envText}' > "$tmp"
    if ! cmp -s "$tmp" "$envfile" 2>/dev/null; then
      cp "$tmp" "$envfile"
      chmod 600 "$envfile"
    fi
    rm -f "$tmp"
    conf=/etc/ssh/sshd_config.d/20-permit-user-env.conf
    if [ ! -f "$conf" ]; then
      printf 'PermitUserEnvironment yes\n' > "$conf"
      /usr/bin/systemctl reload ssh 2>/dev/null || /usr/bin/systemctl reload sshd 2>/dev/null || true
    fi

    # 3) hosts 幂等追加 + oneshot 服务（容器重启后 Docker 重写 /etc/hosts，启动时自动恢复）
    ${hostsScript}
    unit=/etc/systemd/system/ide-extra-hosts.service
    tmp=$(mktemp)
    printf '%s' '${hostsUnit}' > "$tmp"
    sed -i "s|@hostsScript@|${hostsScript}|" "$tmp"
    if ! cmp -s "$tmp" "$unit" 2>/dev/null; then
      cp "$tmp" "$unit"
    fi
    rm -f "$tmp"
    /usr/bin/systemctl daemon-reload >/dev/null 2>&1 || true
    /usr/bin/systemctl enable ide-extra-hosts.service >/dev/null 2>&1 || true
    # restart 而非 start：RemainAfterExit 下 start 对已 active 是 no-op，restart 保证激活时重跑
    /usr/bin/systemctl restart ide-extra-hosts.service >/dev/null 2>&1 || true

    # 4) 已运行服务拿到新环境（skemate Restart=always，重启无副作用；ssh 走通道 2 不动）
    if /usr/bin/systemctl list-unit-files skemate.service >/dev/null 2>&1; then
      /usr/bin/systemctl restart skemate.service >/dev/null 2>&1 || true
    fi
  '';
}
