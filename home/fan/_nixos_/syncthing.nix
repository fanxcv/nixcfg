# syncthing 同步目录忽略规则（与 Mac 端一致：.DS_Store 等垃圾文件不参与同步）
#   .stignore 本身被 syncthing 忽略，不跨设备同步 → 各设备各自配置（Mac 见 home/fan/_darwin_/syncthing.nix）
#   ~/sync 整目录持久化（immutable.nix），.stignore 随目录持久
{ ... }:
{
  home.file."sync/.stignore".text = ''
    // macOS 系统/垃圾文件
    .DS_Store
    .sync-conflict-*.DS_Store
    ._*
    .Spotlight-V100
    .Trashes
    .fseventsd
    .localized
    .apdisk
    .AppleDouble
    .DocumentRevisions-V100
    .TemporaryItems
    .VolumeIcon.icns
    .com.apple.timemachine.donotpresent
    Icon?
    // 子目录 .stignore / verysync 遗留（syncthing 只认根目录 .stignore，子目录的无效）
    .stignore
    .verysync
    // Windows 垃圾
    Thumbs.db
    desktop.ini
    // Office 临时
    ~$*
    // 编辑器/开发临时
    *.swp
    *.swo
    *~
  '';
}
