# Edge 扩展企业策略安装（系统层，root 执行）——替代已失效的 External Extensions JSON 机制
# 背景（151.0.4129.86 实机验证）：Edge 129+ 落实"不可信来源"政策，对 External Extensions JSON
#   安装的扩展（installedby=external）一律禁用（disable_reasons=8192 DISABLE_EXTERNAL_EXTENSION），
#   禁用的扩展不出现在 edge://extensions 列表 → 表现为"插件列表空"。JSON 机制已不可用。
# 正解：ExtensionSettings 策略 force_installed（installedby=policy，不受禁用限制）：
#   - 经 macOS Managed Preferences（/Library/Managed Preferences/com.microsoft.Edge.plist）下发，
#     无 MDM 也生效（root:wheel、644、非 world-writable）
#   - Edge 商店扩展默认从 Edge Add-ons 装；Chrome 商店扩展配 update_url 指向 CWS
#   - Chrome 商店直连不可达（国内网络）→ 依赖 clash 系统代理（clash-verge 常驻，开系统代理后重启 Edge 即装）
# 副作用：force_installed 扩展不可在 edge://extensions 内禁用/卸载（显示"由你的组织管理"），
#   从清单（edge-extensions.nix）移除并部署后 Edge 重启即卸载
{
  pkgs,
  lib,
  tools,
  ...
}:
let
  ext = import (tools.relative "home/fan/_darwin_/gui/apps/edge-ext/data.nix");
  edgeStoreUrl = "https://edge.microsoft.com/extensionwebstorebase/v1/crx";
  chromeStoreUrl = "https://clients2.google.com/service/update2/crx";
  updateUrl = store: if store == "chrome" then chromeStoreUrl else edgeStoreUrl;
  # ExtensionSettings 策略条目：全部 force_installed + 显式 update_url（edge=Edge 商店 / chrome=CWS）
  policyEntries = builtins.concatStringsSep "\n" (
    builtins.map (id: ''
      <key>${id}</key>
      <dict>
        <key>installation_mode</key>
        <string>force_installed</string>
        <key>update_url</key>
        <string>${updateUrl ext.extensions.${id}}</string>
      </dict>
    '') (builtins.attrNames ext.extensions)
  );
  # nix 生成 plist 实体（激活期 install 到 /Library/Managed Preferences）
  plistFile = pkgs.writeText "com.microsoft.Edge.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>ExtensionSettings</key>
      <dict>
    ${policyEntries}
      </dict>
      <key>UpdateDefault</key>
      <integer>2</integer>
    </dict>
    </plist>
  '';
in
{
  # 注意：nix-darwin 26.05 起自定义 system.activationScripts.<名字> 条目不再自动执行
  #   （script.text 只内联内置条目），必须挂到内置入口 extraActivation/postActivation
  # UpdateDefault=2：禁用 Edge 自动更新（EdgeUpdater 策略，macOS ≥89 支持，com.microsoft.Edge 域）
  #   → Edge 主程序不再自行拉起 updater、不再下载 EdgeUpdater 组件（根治 edge.nix 删了又重建的问题）
  #   只禁浏览器本体更新，不影响 ExtensionSettings force_installed 扩展的商店更新
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    # Edge 扩展策略（ExtensionSettings force_installed）+ 更新禁用（UpdateDefault=2）：声明式覆盖，直接 install 覆盖旧文件
    # Managed Preferences 目录须 root:wheel 644（无 MDM 本地策略文件，Edge 启动时读取）
    install -d -m 755 /Library/Managed\ Preferences
    install -m 644 ${plistFile} /Library/Managed\ Preferences/com.microsoft.Edge.plist
    # 属主/组校验（install -d 已建目录时属主可能不对，显式修正）
    chown root:wheel /Library/Managed\ Preferences /Library/Managed\ Preferences/com.microsoft.Edge.plist
  '';
}
