# syncthing 自动注册脚本生成器（darwin activation / nixos oneshot 共用）
#   功能：设备互配（清单驱动，缺者补）+ ~/sync folder 创建/同步 devices + GUI 密码注入（可选）
#   幂等：REST API 检查存在性，仅补缺不删改（GUI 手动配对状态保留）
#   失败策略：API 不可达/读不到 key 时仅警告返回（下次部署补），不阻塞部署
# 用法：
#   tools.syncthingAutoConfig { pkgs; peers = [ { name; id; addr = [ ... ]; } ]; guiPasswordAgePath = null; }
#     guiPasswordAgePath 非空时启用 GUI 密码段（age 解密 → PUT /rest/config/gui，放最后因会触发重启）
#     addr 为设备地址数组（如 [ "tcp://mba-m5:22000" "dynamic" ]）
#     folder 路径恒为 $HOME/sync（darwin 下 = /Users/fan/sync，nix-pve 下 = /home/fan/sync）
{
  pkgs,
  peers,
  guiPasswordAgePath ? null,
}:
let
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  age = "${pkgs.age}/bin/age";
  peersJson = builtins.toJSON peers;
  guiPasswordBlock = if guiPasswordAgePath == null then
    "true # GUI 密码由外部机制管理（nix-pve：agenix guiPasswordFile）"
  else
    ''
      local pw
      pw=$(${age} -d -i "$HOME/.secrets/age-keys.txt" ${guiPasswordAgePath}) || { echo "警告: 解密 syncthing GUI 密码失败"; return 0; }
      local gui
      gui=$(${curl} -sf -H "$hdr" $api/config/gui) || { echo "警告: syncthing API 不可达，GUI 密码未设置"; return 0; }
      gui=$(printf '%s' "$gui" | ${jq} --arg u fan --arg p "$pw" '.user=$u | .password=$p')
      if ${curl} -sf -X PUT -H "$hdr" -H "Content-Type: application/json" -d "$gui" $api/config/gui >/dev/null; then
        echo "[syncthing] GUI 密码已设置"
      else
        echo "警告: syncthing GUI 密码设置失败"
      fi
    '';
in
''
  set_syncthing_autoconfig() {
    local cfg=""
    for c in "$HOME/Library/Application Support/Syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
      [ -f "$c" ] && { cfg="$c"; break; }
    done
    [ -n "$cfg" ] || { echo "警告: syncthing config.xml 未生成，自动注册跳过（首次启动后下次部署补）"; return 0; }

    # 本机 device ID（config.xml 首个 device）
    local self_id
    self_id=$(sed -n 's:.*<device id="\([^"]*\)".*:\1:p' "$cfg" | head -1)
    [ -n "$self_id" ] || { echo "警告: 读不到本机 device ID，自动注册跳过"; return 0; }

    # 等 API 就绪（最多 60s；覆盖 syncthing 重启窗口）
    local i
    for i in $(seq 1 60); do
      ${curl} -sf http://127.0.0.1:8384/rest/noauth/health >/dev/null 2>&1 && break
      sleep 1
    done
    local key
    key=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$cfg" | head -1)
    [ -n "$key" ] || { echo "警告: 读不到 syncthing apikey，自动注册跳过"; return 0; }

    local api=http://127.0.0.1:8384/rest hdr="X-API-Key: $key"
    local peers_json='${peersJson}'

    # ---- 1. 设备注册：清单中缺失者补（不含自己；不动 GUI 已有配对） ----
    ${curl} -sf -H "$hdr" $api/config/devices -o /tmp/st-autoreg-devices.json || { echo "警告: 读设备列表失败，自动注册跳过"; return 0; }
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      local pid pname
      pid=$(printf '%s' "$row" | ${jq} -r '.id')
      pname=$(printf '%s' "$row" | ${jq} -r '.name')
      [ "$pid" = "$self_id" ] && continue
      if ${jq} -e --arg id "$pid" 'any(.[]; .deviceID == $id)' /tmp/st-autoreg-devices.json >/dev/null 2>&1; then
        continue
      fi
      local body
      body=$(printf '%s' "$row" | ${jq} -c --arg pid "$pid" --arg pname "$pname" '{deviceID: $pid, name: $pname, addresses: .addr, compression: "metadata", certName: "", introducer: false, skipIntroductionRemovals: false, introducedBy: "", paused: false, allowedNetworks: [], autoAcceptFolders: false, maxSendKbps: 0, maxRecvKbps: 0, ignoredFolders: [], maxRequestKiB: 0, untrusted: false, remoteGUIPort: 0, numConnections: 0, group: ""}')
      if ${curl} -sf -X POST -H "$hdr" -H "Content-Type: application/json" -d "$body" $api/config/devices >/dev/null; then
        echo "[syncthing] 已注册设备 $pname"
      else
        echo "警告: 注册设备 $pname 失败"
      fi
    done < <(printf '%s' "$peers_json" | ${jq} -c '.[]')

    # ---- 2. ~/sync 文件夹：无则建（共享全部清单+自己），有则补缺设备 ----
    local want_devs
    want_devs=$(printf '%s' "$peers_json" | ${jq} -c --arg self "$self_id" '
      ([.[] | {deviceID: .id}] + [{deviceID: $self}]) | unique_by(.deviceID)
    ')
    ${curl} -fsS -H "$hdr" $api/config/folders -o /tmp/st-autoreg-folders.json || { echo "警告: 读文件夹列表失败，自动注册跳过"; return 0; }
    if ! ${jq} -e 'any(.[]; .id == "sync")' /tmp/st-autoreg-folders.json >/dev/null 2>&1; then
      local fbody
      fbody=$(printf '%s' "$want_devs" | ${jq} -c --arg path "$HOME/sync" '
        {id: "sync", label: "sync", path: $path, type: "sendreceive", rescanIntervalS: 3600, fsWatcherEnabled: true, fsWatcherDelayS: 10, ignorePerms: false, autoNormalize: true, devices: .}
      ')
      if ${curl} -s -X POST -H "$hdr" -H "Content-Type: application/json" -d "$fbody" $api/config/folders >/dev/null; then
        echo "[syncthing] 已创建 ~/sync 文件夹"
      else
        echo "警告: 创建 ~/sync 文件夹失败"
      fi
    else
      # 合并 devices：现有 ∪ 清单(+自己)；path 纠正为 $HOME/sync
      local cur merged same
      cur=$(${curl} -s -H "$hdr" $api/config/folders/sync) || { echo "警告: 读 folder sync 失败"; return 0; }
      merged=$(printf '%s' "$cur" | ${jq} -c --argjson want "$want_devs" --arg home "$HOME" '
        ([.devices[].deviceID] | map({deviceID: .})) as $have
        | .devices = (($have + $want) | unique_by(.deviceID))
        | .path = ($home + "/sync")
      ')
      same=$(printf '%s' "$cur" | ${jq} -r --argjson want "$want_devs" --arg path "$HOME/sync" '
        (([.devices[].deviceID] | sort) == ([$want[].deviceID] | sort)) and (.path == $path)
      ')
      if [ "$same" != "true" ]; then
        if ${curl} -s -X PUT -H "$hdr" -H "Content-Type: application/json" -d "$merged" $api/config/folders/sync >/dev/null; then
          echo "[syncthing] ~/sync 设备列表已更新"
        else
          echo "警告: 更新 ~/sync 设备列表失败"
        fi
      fi
    fi

    # ---- 3. GUI 密码（仅 darwin 侧；nix-pve 由 agenix guiPasswordFile 管理；放最后因 PUT 触发重启） ----
    ${guiPasswordBlock}
  }
  set_syncthing_autoconfig
''
