# syncthing（P2P 文件同步）——三台 Mac 公共（brew formula 见 hosts/_darwin_/base/homebrew.nix）
#   服务：LaunchAgent 自启（RunAtLoad + KeepAlive），登录即启、崩溃自动重启
#   同步：~/sync 目录与 nix-pve 及其他 Mac 组网；设备配对走 GUI（127.0.0.1:8384）
#   注意：syncthing 配置（config.xml/device ID）由 syncthing 自管，不声明式接管
#     （声明式会与 GUI 配对状态冲突，rebuild 覆盖丢失配对）
{
  pkgs,
  lib,
  ...
}:
{
  # ~/sync 同步目录（.keep 占位触发 home-manager 建目录）
  home.file."sync/.keep".text = "";

  # LaunchAgent：登录即启 + KeepAlive 常驻（改配置后 launchctl kickstart -k gui/$(id -u)/syncthing 重启）
  # --no-browser：不弹浏览器；日志 syncthing 自管（配置目录 syncthing.log），不设 StandardOutPath
  launchd.agents.syncthing = {
    enable = true;
    config = {
      ProgramArguments = [ "/opt/homebrew/bin/syncthing" "serve" "--no-browser" ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = "/Users/fan";
    };
  };

  # GUI 登录密码（幂等注入）：syncthing 配置自管，密码经 REST API 设置
  #   流程：age 解密 → 等 syncthing API 就绪（最多 60s）→ GET /rest/config/gui → jq 注入 user/password → PUT
  #   幂等：config.xml 的 gui 段已有 user 则跳过；失败仅警告（syncthing 可能未首次启动，下次部署补）
  home.activation.setSyncthingGuiPassword = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set_syncthing_gui_password() {
      local cfg=""
      for c in "$HOME/Library/Application Support/Syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
        [ -f "$c" ] && { cfg="$c"; break; }
      done
      [ -n "$cfg" ] || { echo "警告: syncthing config.xml 未生成（首次启动后自动补设 GUI 密码）"; return 0; }
      # 幂等：已有 user 跳过
      if grep -q '<user>[^<]' "$cfg"; then
        echo "[syncthing] GUI 密码已设置，跳过"
        return 0
      fi
      # 等 API 就绪（LaunchAgent 已 RunAtLoad 启动，首次生成 config.xml 需数秒）
      local i
      for i in $(seq 1 60); do
        ${pkgs.curl}/bin/curl -sf http://127.0.0.1:8384/rest/noauth/health >/dev/null 2>&1 && break
        sleep 1
      done
      local key
      key=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$cfg" | head -1)
      [ -n "$key" ] || { echo "警告: 读不到 syncthing apikey，GUI 密码未设置"; return 0; }
      local pw
      pw=$(${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" ${../../..}/secrets/syncthing-gui-password.age) || { echo "警告: 解密 syncthing GUI 密码失败"; return 0; }
      local gui
      gui=$(${pkgs.curl}/bin/curl -sf -H "X-API-Key: $key" http://127.0.0.1:8384/rest/config/gui) || { echo "警告: syncthing API 不可达，GUI 密码未设置"; return 0; }
      gui=$(printf '%s' "$gui" | ${pkgs.jq}/bin/jq --arg u fan --arg p "$pw" '.user=$u | .password=$p')
      if ${pkgs.curl}/bin/curl -sf -X PUT -H "X-API-Key: $key" -H "Content-Type: application/json" -d "$gui" http://127.0.0.1:8384/rest/config/gui >/dev/null; then
        echo "[syncthing] GUI 密码已设置"
      else
        echo "警告: syncthing GUI 密码设置失败"
      fi
    }
    set_syncthing_gui_password
  '';
}
