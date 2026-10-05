# Edge 更新策略（系统层，root 执行）：禁用 Edge 自更新，本体版本交给 nix / homebrew cask
# 边界（2026-10 收敛）：扩展不再由 nix 管理——原 ExtensionSettings force_installed 策略已移除，
#   扩展的安装与同步交给 Edge 自身账号同步（历史：Edge 129+ 禁用 External Extensions JSON 后，
#   曾改用 ExtensionSettings 策略下发，现整体撤出，见 home/fan/_darwin_/gui/apps/edge.nix 顶部说明）。
# UpdateDefault=2：禁用 Edge 自动更新（com.microsoft.Edge 域，macOS ≥89 支持）
#   → Edge 主程序不再自行拉起 updater、不再下载 EdgeUpdater 组件
#   （EdgeUpdater 的主动拆卸已撤出，仅保留本策略；见 home/fan/_darwin_/gui/apps/edge.nix 顶部说明）
{
  pkgs,
  lib,
  ...
}:
let
  # nix 生成 plist 实体（激活期 install 到 /Library/Managed Preferences）
  plistFile = pkgs.writeText "com.microsoft.Edge.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>UpdateDefault</key>
      <integer>2</integer>
    </dict>
    </plist>
  '';
in
{
  # 注意：nix-darwin 26.05 起自定义 system.activationScripts.<名字> 条目不再自动执行
  #   （script.text 只内联内置条目），必须挂到内置入口 extraActivation/postActivation
  system.activationScripts.extraActivation.text = lib.mkAfter ''
    # Edge 更新策略：声明式覆盖，直接 install 覆盖旧文件
    # Managed Preferences 目录须 root:wheel 644（无 MDM 本地策略文件，Edge 启动时读取）
    install -d -m 755 /Library/Managed\ Preferences
    install -m 644 ${plistFile} /Library/Managed\ Preferences/com.microsoft.Edge.plist
    # 属主/组校验（install -d 已建目录时属主可能不对，显式修正）
    chown root:wheel /Library/Managed\ Preferences /Library/Managed\ Preferences/com.microsoft.Edge.plist
  '';
}
