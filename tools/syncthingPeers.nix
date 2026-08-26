# syncthing 互配机器清单（单一事实来源：新增机器在此登记，各机下次部署自动互配）
#   id  = 各机 syncthing device ID（REST /rest/system/status 的 myID；或 TLS 22000 证书指纹算法）
#   addr = 设备地址（MagicDNS 名，headscale 下各机 accept-dns 已开；dynamic 兜底发现）
# 注意：本机不在清单不影响（folder 的 devices 自动并入本机 ID，见 syncthingAutoConfig.nix）
# 待补：nix-pve 的 device ID（机器离线未取到，上线后从 GUI 或 TLS 指纹补入）
# 注：mbp-m1 的 MagicDNS 名为 macbookpro（tailscale 注册名），addr 用 macbookpro 而非 mbp-m1
[
  {
    name = "mini-m4";
    id = "Z767O4L-LBDVVEY-DDMDK63-5B6Z3PL-FNXJF4T-QVLF4IV-HTU2BZ3-DSCW6Q3";
    addr = [
      "tcp://mini-m4:22000"
      "dynamic"
    ];
  }
  {
    name = "mba-m5";
    id = "45P4AQI-ZTYFDMK-2YXBUUW-LVGU7ZG-MQJRQQR-KXCKLBV-2MEIJWV-LKH6MQ3";
    addr = [
      "tcp://mba-m5:22000"
      "dynamic"
    ];
  }
  {
    name = "mbp-m1";
    id = "7UILMCV-YXVJK7G-LII7UK4-XZEAKBV-IDBVF5L-EDUXPW4-AGS6BNL-B7P32QA";
    addr = [
      "tcp://macbookpro:22000"
      "dynamic"
    ];
  }
]
