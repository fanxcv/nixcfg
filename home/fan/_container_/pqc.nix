# 关闭 curl 的后量子混合密钥交换（X25519MLKEM768）
#   症状：容器内 curl 打部分站点间歇报
#         curl: (35) TLS connect error: error:0A000126:SSL routines::unexpected eof while reading
#         （`TLS connect error` 这句文案只有 curl 8.17+ 才有，可据此判断是 nix 版 curl）
#   成因：nix 的 curl 链 OpenSSL 3.6.5，默认把 X25519MLKEM768 排在 groups 首位，
#         ClientHello 从 ~310B 膨胀到 ~1.2KB，被部分出口链路上的 DPI / 入口设备间歇丢弃或 RST。
#         宿主 Ubuntu 系统 curl 是 OpenSSL 3.0.13（无该组），故同机器上表现为「宿主完全正常」。
#   实测（2026-11，容器内各 120 次请求同一站点）：
#         系统 curl(3.0.13) 119 成功 / nix curl(3.6.5) 73 成功 / nix curl --curves X25519 120 成功。
#   只保留 curl 一处，理由：
#         · curl 是实测收益最明确、副作用最小的一处（纯数据文件，无全局钩子，groups 仍含 X25519/P-256/P-384）
#         · git 的 http.sslVersion=tlsv1.2 会把所有 https 降级到 TLS 1.2，收益不抵代价，已移除
#         · node 的 NODE_OPTIONS 预加载会影响容器内所有 node 进程，且 pi 的超时真因是 MTU 黑洞
#           （见 _container_/mtu.nix），与 PQC 无关，已移除
#   libcurl 不触发 OpenSSL config 加载（OPENSSL_CONF 对 curl 无效），故只能用 curlrc 的 curves。
{ lib, ... }:
{
  home.file.".curlrc".text = ''
    curves = "X25519:P-256:P-384"
  '';

  # 桌面会话（KasmVNC，以 fan 运行、HOME=/home/fan）不归 HM 管，需单独落同一份配置
  home.activation.pqcSessionUser = lib.hm.dag.entryAfter [ "sessionUser" ] ''
    install -d -o fan -g fan -m 0755 /home/fan
    printf 'curves = "X25519:P-256:P-384"\n' > /home/fan/.curlrc
    chown fan:fan /home/fan/.curlrc
  '';
}
