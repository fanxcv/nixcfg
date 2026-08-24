# fan 专属：tailscale nix 化（nix 包 + state 由 secrets 管理；其他机器此段为空）
echo "==> tailscale（fan 专属：nix 包 + state nix 化）"
# 1. 卸 apt 版（若在），避免双 tailscaled
if dpkg -s tailscale >/dev/null 2>&1; then
  systemctl stop tailscaled 2>/dev/null || true
  apt-get purge -y tailscale >/dev/null
  echo "apt tailscale 已卸载"
fi
# 2. state 落位（仅缺失时；deploy.sh 已从 secrets 解密推送 /tmp/tailscale-state）
if [ ! -f /var/lib/tailscale/tailscaled.state ] && [ -f /tmp/tailscale-state ]; then
  mkdir -p /var/lib/tailscale
  install -m 0600 -o root -g root /tmp/tailscale-state /var/lib/tailscale/tailscaled.state
  rm -f /tmp/tailscale-state
  echo "tailscale state 已从 secrets 归档落位"
fi
# 3. systemd unit（nix 版 tailscaled，默认 state 路径 /var/lib/tailscale/tailscaled.state）
cat > /etc/systemd/system/tailscaled.service <<'UNIT'
[Unit]
Description=Tailscale daemon (nix 管理)
After=network-online.target
Wants=network-online.target
[Service]
ExecStart=/root/.nix-profile/bin/tailscaled
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now tailscaled
sleep 3
/root/.nix-profile/bin/tailscale status 2>&1 | head -2 || echo "警告: tailscale status 失败（稍后手动 tailscale up --authkey 检查）"
echo "tailscale 就绪（nix 包 + nix state）"
