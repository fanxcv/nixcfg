# 关闭 OpenSSL 3.5+ 默认启用的后量子混合密钥交换（X25519MLKEM768）
#   症状：容器内 curl / git 打部分站点间歇报
#         curl: (35) TLS connect error: error:0A000126:SSL routines::unexpected eof while reading
#         （`TLS connect error` 这句文案只有 curl 8.17+ 才有，可据此判断是 nix 版 curl）
#   成因：nix 的 curl / git / node 链 OpenSSL 3.6.5，默认把 X25519MLKEM768 排在 groups 首位，
#         ClientHello 从 ~310B 膨胀到 ~1.2KB，被部分出口链路上的 DPI / 入口设备间歇丢弃或 RST。
#         宿主 Ubuntu 系统 curl 是 OpenSSL 3.0.13（无该组），故同机器上表现为「宿主完全正常」。
#   实测（2026-11，容器内各 120 次请求同一站点）：
#         系统 curl(3.0.13) 119 成功 / nix curl(3.6.5) 73 成功 / nix curl --curves X25519 120 成功。
#   三处分别落，因为没有任何单一开关能全覆盖：
#         curl  —— ~/.curlrc 的 curves（libcurl 不触发 OpenSSL config 加载，OPENSSL_CONF 无效）
#         git   —— http.sslVersion（libcurl 无 groups 配置项，且 git 不读 curlrc）
#         node  —— compose 的 NODE_OPTIONS 预加载（镜像内 /etc/pqc-classic.cjs，见 docker/ide/ubuntu/Dockerfile）
#   代价：TLS 1.2 无 TLS 1.3 的 0-RTT 等特性，安全强度不受影响；groups 保留 X25519/P-256/P-384 覆盖现有全部站点。
{ lib, pkgs, ... }:
{
  home.file.".curlrc".text = ''
    curves = "X25519:P-256:P-384"
  '';

  programs.git.settings.http.sslVersion = "tlsv1.2";

  # 桌面会话（KasmVNC，以 fan 运行、HOME=/home/fan）不归 HM 管，需单独落同一份配置
  home.activation.pqcSessionUser = lib.hm.dag.entryAfter [ "sessionUser" ] ''
    install -d -o fan -g fan -m 0755 /home/fan
    printf 'curves = "X25519:P-256:P-384"\n' > /home/fan/.curlrc
    chown fan:fan /home/fan/.curlrc
    # 只改这一个键，保留 fan 侧既有 git 配置；文件不存在时 git 会创建
    ${pkgs.git}/bin/git config --file /home/fan/.gitconfig --replace-all http.sslVersion tlsv1.2
    chown fan:fan /home/fan/.gitconfig
  '';
}
