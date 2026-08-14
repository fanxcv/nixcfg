# skemate（自研终端复用服务）——mini-m4 专属：包 + 配置（nix 管理）
#   安装：overlays/skemate.nix 提供 pkgs.skemate（官方构建，platforms 含 aarch64-darwin）
#   配置：tunnel.yaml + config.json 由 nix 管理（含 token/密码 hash，走 agenix 加密，
#         明文在 secrets/source/hosts/mini-m4/，加密后 secrets/hosts/mini-m4/*.age）
#       其他文件（agent.sock/devices.json/layout.json/preferences.json/session.json/log/pid）
#       是运行时文件，skemate 自管，不声明
#   服务：本机 skemate 手工启动（非 LaunchAgent）；改配置需重启 skemate 生效
{ pkgs, lib, ... }:
{
  home.packages = [ pkgs.skemate ];

  home.activation.setupSkemateConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    setup_skemate_config() {
      local dir="$HOME/Library/Application Support/skemate"
      local key="$HOME/.secrets/age-keys.txt"
      if [ ! -f "$key" ]; then
        echo "警告: 未找到 $key，skemate 配置跳过（请把 age 私钥放到该路径）"
        return 0
      fi
      mkdir -p "$dir"
      local age_bin="${pkgs.age}/bin/age"
      local base=${../../..}/secrets/hosts/mini-m4
      if "$age_bin" -d -i "$key" -o "$dir/tunnel.yaml" "$base/skemate-tunnel.yaml.age"; then
        chmod 644 "$dir/tunnel.yaml"
      else
        echo "警告: skemate tunnel.yaml 解密失败（保留现有文件）"
      fi
      if "$age_bin" -d -i "$key" -o "$dir/config.json" "$base/skemate-config.json.age"; then
        chmod 600 "$dir/config.json"
      else
        echo "警告: skemate config.json 解密失败（保留现有文件）"
      fi
      echo "[skemate] 配置已写入（tunnel.yaml/config.json，nix 管理；改配置后需重启 skemate 生效）"
    }
    setup_skemate_config
  '';
}
