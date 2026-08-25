# PVE 系统层配置渲染（公共：所有 PVE 机器同一套文件，参数来自机器层）
# 输出 /nix/store/...-pve-sysfiles/：apt 源（debian/security/pve-no-subscription）+ resolv.conf + grub + modprobe + static-ip
# 机器层 pve/<host>/default.nix 提供：dns / mirror / suite / grubCmdline / modprobePublic / modprobeHost / ip / gateway
{ pkgs, lib, dns, mirror, suite, grubCmdline, modprobePublic ? "", modprobeHost ? { }, tailscaleForward ? false, ip ? "", gateway ? "" }:
pkgs.runCommand "pve-sysfiles" { } ''
  mkdir -p $out

  # Debian 主源（deb822，镜像）
  cat > $out/debian.sources <<EOF
  Types: deb
  URIs: ${mirror}/debian/
  Suites: ${suite} ${suite}-updates ${suite}-backports
  Components: main contrib non-free non-free-firmware
  Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
  EOF

  # Debian security 源（deb822，镜像）
  cat > $out/debian-security.sources <<EOF
  Types: deb
  URIs: ${mirror}/debian-security/
  Suites: ${suite}-security
  Components: main contrib non-free non-free-firmware
  Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
  EOF

  # PVE no-subscription 源（镜像；替换 enterprise 源，黄色提示根源）
  cat > $out/pve-no-subscription.list <<EOF
  deb ${mirror}/proxmox/debian/pve ${suite} pve-no-subscription
  EOF

  # DNS（/etc/resolv.conf 直写；PVE 9 无 systemd-resolved，resolv.conf 由安装器/网络模块生成，部署时覆盖）
  cat > $out/resolv.conf <<EOF
  # 由 nixcfg pve 渲染（公共 DNS，见 pve/default.nix）；网络重启若覆盖，请在 /etc/network/interfaces 配置 dns-nameservers
  ${builtins.concatStringsSep "\n" (map (d: "nameserver " + d) dns)}
  EOF

  # 静态 IP（/etc/network/interfaces 的 vmbr0 段；apply 幂等替换 address/gateway，见 apply.sh）
  ${lib.optionalString (ip != "") ''
  cat > $out/static-ip.conf <<EOF
  # 由 nixcfg pve 渲染（静态 IP，见 pve/<host>/default.nix）
  ip=${ip}
  gateway=${gateway}
  EOF
  ''}

  # GRUB（/etc/default/grub；GRUB_CMDLINE_LINUX_DEFAULT 含公共参数）
  cat > $out/grub <<EOF
  GRUB_DEFAULT=0
  GRUB_TIMEOUT=5
  GRUB_DISTRIBUTOR=\`lsb_release -i -s 2> /dev/null || echo Debian\`
  GRUB_CMDLINE_LINUX_DEFAULT="${builtins.concatStringsSep " " grubCmdline}"
  GRUB_CMDLINE_LINUX=""
  EOF

  # sysctl（99-pve.conf：IP 转发——PVE 9 不再自带该文件，升级后转发默认关，tailscale 网关/VM NAT 需开）
  cat > $out/99-pve.conf <<EOF
  net.ipv4.ip_forward=1
  net.ipv6.conf.all.forwarding=1
  EOF

  # modprobe（公共：所有机器统一 nixcfg-public.conf；机器专属：同名覆盖原文件）
  mkdir -p $out/modprobe
  cat > $out/modprobe/nixcfg-public.conf <<'EOF'
  ${modprobePublic}
  EOF
  ${builtins.concatStringsSep "\n" (lib.mapAttrsToList (fname: content: ''
    cat > $out/modprobe/${fname} <<'CONF'
    ${content}
    CONF
  '') modprobeHost)}

  # tailscale 转发规则（iptables-restore 格式；仅 tailscale 网关机渲染，apply 段写 unit 持久化）
  ${lib.optionalString tailscaleForward ''
  cat > $out/tailscale-forward.rules <<'EOF'
  *nat
  -A POSTROUTING -o tailscale0 -j MASQUERADE
  COMMIT
  *filter
  -A FORWARD -o tailscale0 -j ACCEPT
  COMMIT
  EOF
  ''}
''
