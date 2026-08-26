# Tailscale App 版（brew cask tailscale-app，App Store 版）声明式管理：
#   1. headscale 登录：激活脚本幂等执行 tailscale login --login-server <URL> --authkey <agenix 解密>
#      登录态持久化在 App 容器偏好（io.tailscale.ipn.macsys），此后 status 非零才触发登录
#   2. 后台自启：App 自带登录项（io.tailscale.ipn.macsys.login-item-helper），nix 不接管，
#      只做健康检查——登录项缺失时 open -a Tailscale 重建
#   App Store 版限制：CLI 经 XPC 与 GUI App 通信，登录时需 App 进程在位（脚本已兜底 open）
#   authkey 轮换：headscale 上 headscale preauthkeys create -r -e 0 生成 → 写入
#   secrets/source/tailscale-headscale-authkey → ./secrets/encrypt.sh --force 重加密 → 重部署
{
  pkgs,
  lib,
  config,
  ...
}:
let
  # headscale 服务器（若部署在子路径，补在 URL 末尾，如 https://host/headscale）
  headscaleUrl = "https://headscale.fan-x.fun";
  # 三台 mac 共享同一 headscale；authkey 解密到用户域（App 版登录走用户会话）
  authKeyFile = ../../../secrets/headscale-auth-key.age;
  authKeyPath = "${config.home.homeDirectory}/.secrets/tailscale-headscale-authkey";
in
{
  # authkey 解密（统一 secrets 架构：activation 直接 age -d，失败即部署失败，见 _common_/secrets.nix）
  home.activation.decryptTailscaleAuthkey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" -o "${authKeyPath}" ${authKeyFile}
  '';

  home.activation.setupTailscaleHeadscale = lib.hm.dag.entryAfter [ "decryptTailscaleAuthkey" ] ''
    setup_tailscale_headscale() {
      local ts="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
      local keyfile="${authKeyPath}"
      local server="${headscaleUrl}"
      # 节点名：系统 LocalHostName（mkDarwinConfig 注入 networking.hostName = mba-m5/mbp-m1/mini-m4）
      local hn
      hn="$(scutil --get LocalHostName 2>/dev/null)" || hn="$(hostname -s)"

      [ -x "$ts" ] || { echo "tailscale: App 未安装，跳过"; return 0; }

      # App 进程兜底：App Store 版 CLI 经 XPC 与 App 通信，App 未跑时 login 失败
      # （系统工具走 activatePathFix 补全的 PATH，见 _common_/path.nix）
      pgrep -q -f "Tailscale.app/Contents/MacOS/Tailscale" || open -a Tailscale
      sleep 2

      if "$ts" status >/dev/null 2>&1; then
        echo "tailscale: 已登录，跳过 headscale 登录"
      elif [ -f "$keyfile" ]; then
        # 注册时即指定节点名 + accept-routes（accept-dns 默认 true，显式声明）
        if out=$("$ts" login --login-server="$server" --authkey "$(cat "$keyfile")" \
          --hostname="$hn" --accept-routes=true --accept-dns=true 2>&1); then
          echo "tailscale: headscale 登录成功（$server ，节点名 $hn ）"
        else
          echo "警告: tailscale headscale 登录失败：$out"
          echo "       （headscale 服务器可达？authkey 过期？headscale preauthkeys create -r 重新生成后重加密）"
        fi
      else
        echo "警告: 未找到 $keyfile ，跳过自动登录"
        echo "       （headscale preauthkeys create -r 生成 key → secrets/source/ → encrypt.sh 后重部署）"
      fi

      # 偏好统一收敛（幂等）：已登录机器也更新节点名/路由/DNS
      # --accept-routes：接受其他节点广告的子网路由；--accept-dns：接受 headscale 下发的
      #   MagicDNS 配置（后端 nameserver 在 headscale 服务端 dns.nameservers 配）
      if "$ts" set --hostname="$hn" --accept-routes=true --accept-dns=true >/dev/null 2>&1; then
        echo "tailscale: 节点名=$hn ，accept-routes/accept-dns 已启用"
      else
        echo "警告: tailscale set 失败（未登录或 App 未就绪），稍后手动执行："
        echo "       tailscale set --hostname=$hn --accept-routes=true --accept-dns=true"
      fi

      # 自启健康检查：App Store 版登录项标签
      if ! launchctl print "gui/$UID/io.tailscale.ipn.macsys.login-item-helper" >/dev/null 2>&1; then
        echo "tailscale: 登录项缺失，open -a Tailscale 重建"
        open -a Tailscale
      fi
    }
    setup_tailscale_headscale
  '';

  # App 偏好收敛（defaults 域 io.tailscale.ipn.macsys，幂等）：
  #   SUEnableAutomaticChecks / SUScheduledCheckInterval：Sparkle 键，关闭自动检查更新
  #   HideDockIcon：隐藏 Dock 图标
  # 生效时机：重启 App 完整生效（HideDockIcon 通常实时监听生效）；不 killall——
  # 远程经 tailnet SSH 部署时断网会中断会话
  home.activation.convergeTailscalePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    defaults write io.tailscale.ipn.macsys SUEnableAutomaticChecks -bool false
    defaults write io.tailscale.ipn.macsys SUScheduledCheckInterval -int 0
    defaults write io.tailscale.ipn.macsys HideDockIcon -bool true
    if pgrep -q -f "Tailscale.app/Contents/MacOS/Tailscale"; then
      echo "tailscale: App 偏好已写入（关自动更新/隐藏 Dock 图标），重启 App 后完整生效"
    fi
  '';
}
