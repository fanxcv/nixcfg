# syncthing 互配机器清单（单一事实来源：新增机器在此登记，各机下次部署自动互配）
#   peers.id   = 各机 syncthing device ID（REST /rest/system/status 的 myID；或 TLS 22000 证书指纹算法）
#   peers.addr = 设备地址（MagicDNS 名，headscale 下各机 accept-dns 已开；dynamic 兜底发现）
#   idePeers   = 三个 ide 容器（仅参与 share 目录）：容器无 tailscale，地址仅 dynamic
#   retired    = 已退役设备：各机部署时从 devices 与各 folder 中删除
#                （自动注册脚本只补缺不删改，退役设备不登记就会永久残留在每台机器上）
# 目录与成员：~/sync = peers（现有机器之间）；~/share = peers + idePeers（含三个 ide 容器）
# 注意：本机不在清单不影响（folder 的 devices 自动并入本机 ID，见 syncthingAutoConfig.nix）
# 注：mbp-m1 的 MagicDNS 名为 macbookpro（tailscale 注册名），addr 用 macbookpro 而非 mbp-m1
{
  peers = [
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
      name = "nix-pve";
      id = "USWSSMC-KP4K3H4-ESKCMRQ-COEBIC5-YBMWBZY-U44EZAM-NJ6AGKU-ORREOAF";
      addr = [
        "tcp://nix-pve:22000"
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
    {
      # 现役 nix-lenovo = ThinkBook 14 G6+ AHP（新装，device ID 与旧机 nix-book 不同）
      name = "nix-lenovo";
      id = "2UPF4J3-DVQYRRT-GNU3JB2-77ZZFYE-NK2W6LL-D6UYNXD-LD7TBTY-IGHTYQR";
      addr = [
        "tcp://nix-lenovo:22000"
        "dynamic"
      ];
    }
    {
      # ASUS Zenbook UM5302TA（与 Windows 双系统），ID 取自真机 config.xml
      name = "nix-asus";
      id = "QWB5QEJ-5CTWUWN-23C2TGU-COZPFQX-PHGIFZR-DFTNGEV-473LBFE-CU3MIA2";
      addr = [
        "tcp://nix-asus:22000"
        "dynamic"
      ];
    }
  ];
  # ide 容器（ide-si / ide-lenovo / ide-mac）：仅参与 share 目录，不参与 sync
  #   device ID 取自容器 /home/fan/.config/syncthing/config.xml 的首个 <device>（本机），
  #   并以 cert.pem 复算交叉核对（syncthing 算法：sha256(DER) → base32 → 每 13 字符追 1 位 luhn32 校验）；
  #   ide-si 的 ID 来自用户提供值，已过 luhn 校验位四段（证书复算待该机可达时补）
  #   容器无 tailscale，地址仅 dynamic（全局发现/中继）
  #   本清单为空时不影响：现有机器的 share 目录照建，只是尚未并入 ide 容器
  idePeers = [
    {
      # 容器 hostname ide-si（宿主 host-10-31-144-11），2026-10-15 回填
      name = "ide-si";
      id = "QJDHO3S-FPGZPYC-QT5M5XN-UHEYL23-OWL7WQK-JZKLI7B-S3MMNTB-SNXT2AV";
      addr = [ "dynamic" ];
    }
    {
      # 容器 hostname lenovo-ide（宿主 pve.mi.fan.ts），2026-10-15 回填
      name = "ide-lenovo";
      id = "JJZD2VD-LXDMQPP-SXEKQRT-KIACVKO-FGZXRUH-VQ2WSRK-THXGYVW-WD3N7AQ";
      addr = [ "dynamic" ];
    }
    {
      # 容器 hostname mac-ide（宿主 ske-mac.fan.ts），2026-10-15 回填
      name = "ide-mac";
      id = "EKKR6YE-ZHL2WCP-E4HPSX2-SRLXNGA-XCPGHLA-5GSL6LU-TMQ5THE-2FSPVAM";
      addr = [ "dynamic" ];
    }
  ];
  retired = [
    # nix-book（无界14S 旧笔记本）2026-10 换 ThinkBook 后退役，同一台机器的现役 ID 见上方 peers.nix-lenovo
    {
      name = "nix-book";
      id = "3BUAVRP-MP4LTY6-7Q72EOI-HRCOYYK-V2NQ54J-POLLKSW-FMJY7E3-IHJOFQW";
    }
  ];
}
