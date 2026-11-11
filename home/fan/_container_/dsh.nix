# DeepSeek Harness（dsh）+ dsh-im（微信 iLink 渠道）常驻 —— ide-mac 专属
#   为何走激活脚本而非 nix 包：dsh 与插件是 npm 生态（插件由 `dsh plugin` 经 pnpm 装进 DSH_HOME），
#     且 dsh 依赖 native 模块（node-pty/koffi）的 install scripts，nix 打包成本高且随上游漂移；
#     nix 侧只保证 node/pnpm 与 systemd 常驻，运行时安装交给激活脚本（同 miseInstall 先例，幂等）。
#   npm -g 必须显式 --prefix $HOME/.local：nix 的 node 前缀是只读 store，
#     否则报 ENOENT lstat <store>/lib（同 _nixos_/npm.nix 记的坑）。
#   持久化靠 compose（docker/ide/docker-compose-mac.yml）：./local → /root/.local（dsh/pnpm）、
#     ./dsh → /root/.dsh（插件与微信登录态）；未挂载时容器重建丢登录态，需重新扫码。
#   自启：容器 PID1 即 systemd，写 /etc/systemd/system/dsh-web.service（unit 模板 ./dsh-web.service）；
#     ExecStart 用 store 内 node 绝对路径 —— dsh 的 shebang 是 /usr/bin/env node，
#     不注入 PATH 会报 /usr/bin/env: 'node': No such file or directory（2026-11 实测）
{ pkgs, lib, hostName, ... }:
lib.mkIf (hostName == "ide-mac") {
  home.packages = [ pkgs.pnpm ];

  # dsh 本体（已装则跳过；失败只警告，不阻塞容器部署）
  home.activation.dshInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    log=/tmp/dsh-install.log
    if [ -x "$HOME/.local/bin/dsh" ]; then
      echo "[dsh] 已安装，跳过"
    elif ${pkgs.nodejs_26}/bin/npm install -g --prefix "$HOME/.local" @deepseek-ai/dsh >"$log" 2>&1; then
      echo "[dsh] 安装完成（日志 $log）"
    else
      echo "警告: dsh 安装失败（下次激活重试；日志 $log 尾部）："
      tail -n 10 "$log" 2>/dev/null | sed 's/^/  /'
    fi
  '';

  # dsh-im 插件：微信走腾讯 iLink（扫码绑定）。dsh plugin 把参数转发给 pnpm，故需 pnpm 在 PATH
  home.activation.dshImInstall = lib.hm.dag.entryAfter [ "dshInstall" ] ''
    log=/tmp/dsh-im-install.log
    if [ ! -x "$HOME/.local/bin/dsh" ]; then
      echo "警告: dsh 未就绪，跳过 dsh-im 安装"
    elif "$HOME/.local/bin/dsh" plugin --profile web list 2>/dev/null | grep -q "@xmanrui/dsh-im"; then
      echo "[dsh-im] 已安装，跳过"
    elif env PATH="${pkgs.nodejs_26}/bin:${pkgs.pnpm}/bin:$HOME/.local/bin:$PATH" \
         "$HOME/.local/bin/dsh" plugin --profile web add -w @xmanrui/dsh-im >"$log" 2>&1; then
      echo "[dsh-im] 安装完成（日志 $log）"
    else
      echo "警告: dsh-im 安装失败（下次激活重试；日志 $log 尾部）："
      tail -n 10 "$log" 2>/dev/null | sed 's/^/  /'
    fi
  '';

  home.activation.dshWebService = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    unit=/etc/systemd/system/dsh-web.service
    tmp=$(mktemp)
    sed -e "s|@node@|${pkgs.nodejs_26}/bin/node|" \
        -e "s|@dshbin@|/root/.local/lib/node_modules/@deepseek-ai/dsh/lib/bin.js|" \
        ${./dsh-web.service} > "$tmp"
    unit_changed=0
    if ! cmp -s "$tmp" "$unit"; then
      cp "$tmp" "$unit"
      unit_changed=1
    fi
    rm -f "$tmp"
    # 无条件：确保 systemd 认识 unit 且已启用（幂等）；失败输出真实错误
    if ! /usr/bin/systemctl daemon-reload; then
      echo "警告: systemctl daemon-reload 失败，错误如上"
    fi
    if ! /usr/bin/systemctl enable dsh-web.service; then
      echo "警告: systemctl enable dsh-web.service 失败，错误如上（容器重启后不会自启）"
    fi
    # 重启条件：unit 变更，或服务未存活（崩溃循环时 ActiveState=activating，is-active 会误判）
    state=$(/usr/bin/systemctl show -p ActiveState --value dsh-web.service 2>/dev/null || echo unknown)
    if [ "$unit_changed" = "1" ] || [ "$state" != "active" ]; then
      /usr/bin/systemctl restart dsh-web.service
      sleep 3
      state=$(/usr/bin/systemctl show -p ActiveState --value dsh-web.service 2>/dev/null || echo unknown)
      if [ "$state" = "active" ]; then
        echo "===> dsh-web.service 已启动（Web UI http://127.0.0.1:3080 ，访问令牌见 journalctl -u dsh-web）"
      else
        echo "警告: dsh-web.service 未存活（当前状态 $state ），最近日志："
        /usr/bin/journalctl -u dsh-web.service -n 10 --no-pager 2>/dev/null || true
      fi
    fi
  '';
}
