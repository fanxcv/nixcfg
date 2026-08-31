# skemate（自研终端复用服务）——mini-m4 专属：包 + 配置 + LaunchAgent 自启
#   安装：overlays/skemate.nix 提供 pkgs.skemate（官方构建，platforms 含 aarch64-darwin）
#   配置：tunnel.yaml 整文件由 nix 管理（age 加密，明文在 secrets/source/hosts/mini-m4/）；
#         config.json 仅 password 字段由 nix 管理——存在则只覆盖 password（保留用户手动
#         配置的其他字段），不存在则新建仅含 password 的文件；其余字段用户自管
#       其他文件（agent.sock/devices.json/layout.json/preferences.json/session.json/log/pid）
#       是运行时文件，skemate 自管，不声明
#   服务：LaunchAgent（launchd.agents.skemate，RunAtLoad + KeepAlive）——登录即启、崩溃自动重启；
#         配置解密先于 agent 加载（entryBefore writeBoundary），部署后配置与服务同步就位
{
  pkgs,
  lib,
  config,
  ...
}:
{
  home.packages = [ pkgs.skemate ];

  # 安装了 skemate → 部署命令须 --impure（shells.nix deployCmd 按 softwares.skemate.enable 门控）
  softwares.skemate.enable = true;

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
