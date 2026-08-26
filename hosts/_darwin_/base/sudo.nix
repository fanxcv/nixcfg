# sudoers 追加配置（nix-darwin 写入 /etc/sudoers.d/10-nix-darwin-extra-config，不接管主文件）
# fan→fan 免密（同用户切换，零提权）：nix-darwin 的 system.defaults 写入链
#   （launchctl asuser <uid> sudo --user=fan -- defaults write ...）在 asuser 环境无 tty，
#   且部署构建耗时长、sudo 凭据缓存（5 分钟）可能已过期 → 无免密时写入静默失败
#   （实测：rebuild 后 AppleInterfaceStyle 键消失、外观回浅色，Dock 等旧值残留掩盖了失败）
_: {
  security.sudo.extraConfig = ''
    # defaults 写入链：fan 免密切到 fan（asuser 无 tty 环境）
    fan ALL=(fan) NOPASSWD: ALL
  '';
}
