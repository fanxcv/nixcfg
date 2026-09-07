# skemate（自研终端复用服务）——mini-m4 专属：包 + 配置 + LaunchAgent 自启
#   安装：overlays/skemate.nix 提供 pkgs.skemate（官方构建，flake.lock 锁定 rev，升级 nix flake update skemate）
#   配置：tunnel.yaml 整文件由 nix 管理（age 加密，明文在 secrets/source/hosts/mini-m4/）；
#         config.json 仅 password 字段由 nix 管理——存在则只覆盖 password（保留用户手动
#         配置的其他字段），不存在则新建仅含 password 的文件；其余字段用户自管
#       其他文件（agent.sock/devices.json/layout.json/preferences.json/session.json/log/pid）
#       是运行时文件，skemate 自管，不声明
#   服务：LaunchAgent（launchd.agents.skemate，RunAtLoad + KeepAlive）——登录即启、崩溃自动重启；
#         配置解密先于 agent 加载（entryBefore writeBoundary），部署后配置与服务同步就位；
#         更新后 agent 换血见下方 skemateAgentRefresh（serve 由 nix-darwin launchd reload 换新，
#         agent 是 setsid 独立进程不随 serve 重启，须显式杀旧 agent 让新 serve 拉起新 agent）
{
  pkgs,
  lib,
  ...
}:
{
  home.packages = [ pkgs.skemate ];

  # 配置解密（先于 writeBoundary → 早于 setupLaunchAgents 的 agent 加载；失败即部署失败，
  # 与 _common_/secrets.nix 的统一 secrets 架构一致）
  home.activation.setupSkemateConfig = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    setup_skemate_config() {
      local dir="$HOME/Library/Application Support/skemate"
      local age_bin="${pkgs.age}/bin/age"
      local base=${../../..}/secrets/hosts/mini-m4
      mkdir -p "$dir"
      "$age_bin" -d -i "$HOME/.secrets/age-keys.txt" -o "$dir/tunnel.yaml" "$base/skemate-tunnel.age"
      chmod 644 "$dir/tunnel.yaml"
      # config.json：nix 只管理 password 字段——存在则仅覆盖 password（保留用户手动配置），
      # 不存在则新建仅含 password 的文件；先解密到临时文件再合并，避免整文件覆盖丢字段
      local tmp="$dir/.config.json.tmp"
      "$age_bin" -d -i "$HOME/.secrets/age-keys.txt" -o "$tmp" "$base/skemate-config.age"
      if [ -f "$dir/config.json" ]; then
        ${pkgs.jq}/bin/jq --arg pw "$(${pkgs.jq}/bin/jq -r .password "$tmp")" '.password = $pw' "$dir/config.json" > "$tmp.merged"
        mv "$tmp.merged" "$dir/config.json"
      else
        ${pkgs.jq}/bin/jq '{ password }' "$tmp" > "$dir/config.json"
      fi
      rm -f "$tmp"
      chmod 600 "$dir/config.json"
      echo "[skemate] 配置已写入（tunnel.yaml 整文件；config.json 仅 password 字段，nix 管理）"
    }
    setup_skemate_config
  '';

  # 更新后 agent 换血：nix-darwin 的 launchd reload（userLaunchd）先于 HM 激活
  # （postActivation）执行，故此处 serve 已是新二进制；agent 是 serve 用 setsid 拉起的
  # 独立进程，不随 serve 重启，旧 agent 会一直跑旧二进制。检测 agent 进程二进制路径
  # != 当前 store 路径 → 杀掉，新 serve 的重连循环自动从新二进制拉起新 agent
  # （skemate 自身逻辑）。serve 仍是旧二进制（单独跑 home-manager switch 未走
  # darwin-rebuild）时跳过，避免杀 agent 破坏 serve 内存中的会话树。
  home.activation.skemateAgentRefresh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    new_bin="${pkgs.skemate}/bin/skemate"
    serve_pid=$(pgrep -f "skemate serve" 2>/dev/null | head -1 || true)
    serve_bin=$(ps -p "$serve_pid" -o comm= 2>/dev/null | tr -d ' ' || true)
    if [ -n "$serve_bin" ] && [ "$serve_bin" = "$new_bin" ]; then
      for pid in $(pgrep -f "skemate agent" 2>/dev/null || true); do
        bin=$(ps -p "$pid" -o comm= 2>/dev/null | tr -d ' ' || true)
        if [ -n "$bin" ] && [ "$bin" != "$new_bin" ]; then
          echo "[skemate] 旧 agent 二进制 ($bin) 与当前版本 ($new_bin) 不一致，重启 agent"
          kill "$pid" 2>/dev/null || true
        fi
      done
    fi
  '';

  # LaunchAgent：登录即启 + KeepAlive 常驻（改配置后 launchctl kickstart -k 重启生效）
  # 日志：skemate 自管（~/Library/Application Support/skemate/skemate.log 等运行时文件），
  #   不设 StandardOutPath——launchd 追加模式不截断，长期运行会无限增长
  launchd.agents.skemate = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.skemate}/bin/skemate"
        "serve"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = "/Users/fan";
    };
  };
}
