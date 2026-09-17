# ide-si 容器系统环境接管：代理/环境变量 —— 替代 docker-compose 的 environment
# 背景：compose 注入的变量修改必须重建容器；nix 激活直接写入，免重建，nix run 即生效
# 通道（全覆盖）：
#   systemd 系统服务 → EnvironmentFile 显式引用 /etc/environment.d/zz-ide-proxy.conf（environment.d 只对
#     user 实例生效，系统服务不读；需要代理的系统服务（如 ide-auto-deploy.service）在 unit 里 EnvironmentFile 引用）
#   shell            → home.sessionVariables（.zshenv）
#   SSH 会话         → ~/.ssh/environment（PermitUserEnvironment，sshd 无需重启，覆盖同名变量）
#   JVM 进程         → JAVA_TOOL_OPTIONS（tb-cli 等 JVM 不读 shell 代理，注入 JVM 系统属性）
# 过渡期：compose 同值保留双保险；改值只改这里；稳定后可从 compose 移除
# 范围：仅本机（ide-si）代理；内网 hosts 两台 ide 共用（见 ../_container_/extra-hosts.nix）；lenovo 国内直连无代理

{ lib, ... }:
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

    # 3) 已运行服务拿到新环境（skemate Restart=always，重启无副作用；ssh 走通道 2 不动）
    if /usr/bin/systemctl list-unit-files skemate.service >/dev/null 2>&1; then
      /usr/bin/systemctl restart skemate.service >/dev/null 2>&1 || true
    fi
  '';
}
