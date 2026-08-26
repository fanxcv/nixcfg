# RustDesk 客户端静态配置（macOS 三台共享）
# 配置注入（rendezvous/key/options，fan + root 双域）在系统层 hosts/_darwin_/base/rustdesk.nix
# （root 激活，无 sudo 桥接）；本文件只声明整文件静态配置
# 注：RustDesk_hwcodec.toml 不做静态声明——app 启动会规范化重写该文件（symlink 被覆盖成
#   普通文件），HM 每次部署报 in-the-way 冲突；硬件编解码改由 app/GUI 自管
_: {
  home.file."Library/Preferences/com.carriez.RustDesk/RustDesk_default.toml".source =
    ./rustdesk/RustDesk_default.toml;
}
