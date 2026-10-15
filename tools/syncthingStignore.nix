# syncthing 同步目录忽略规则（Mac / NixOS 真机 / ide 容器共用同一份）
#   .stignore 本身被 syncthing 忽略、不跨设备同步，故各设备须各自写入（本文件即唯一来源）
''
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
''
