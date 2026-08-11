# Microsoft Edge 扩展声明式安装（macOS External Extensions 机制，三台共享）
# 官方机制：~/Library/Application Support/Microsoft Edge/External Extensions/<CRX-ID>.json
#   JSON 内容 {"update_url": "https://edge.microsoft.com/extensionwebstorebase/v1/crx"}
#   （Edge 商店扩展）或 "https://clients2.google.com/service/update2/crx"（Chrome 商店）
# 扩展 ID 在 edge://extensions 的扩展 URL 末尾（32 位小写字母数字）
# 启用方法：把下方注释示例取消注释，ID 换成目标扩展即可
# 注意：home.file 默认 symlink 到 nix store；若 Edge 不识别（扩展没出现），
#   改为 activation 脚本 cp 成实体文件（如 rustdesk.nix 的套路）

_:
{
  home.file = {
    # 示例：uBlock Origin Lite（Chrome 商店）
    # "Library/Application Support/Microsoft Edge/External Extensions/cjpalhdlnbpafiamejdnhcphjbkeiagm.json" = {
    #   text = ''{"update_url": "https://clients2.google.com/service/update2/crx"}'';
    # };
    # 示例：Bitwarden（Edge 商店）
    # "Library/Application Support/Microsoft Edge/External Extensions/jbigncfhogdpiibgndnbjcdofobmkpdo.json" = {
    #   text = ''{"update_url": "https://edge.microsoft.com/extensionwebstorebase/v1/crx"}'';
    # };
  };
}
