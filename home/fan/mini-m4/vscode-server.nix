# vscode-server 扩展 nix 管理（mini-m4 作为 SSH 远程开发服务器）
# 其他电脑的 VSCode 通过 Remote-SSH 连入时，server 端扩展来自 nix store
# （~/.vscode-server/extensions 链接；vscode-server 本体由客户端自动下载，版本跟客户端走）
# 扩展清单与客户端同源（docs/tsln-vscode.yaml，封装见 modules/home/vscode.nix）
# 注意：扩展由 nix 锁定，客户端侧手动安装扩展会失败；增删扩展 = 改清单 + 重新部署
# 部署前请断开所有 VSCode 远程连接（激活会 rm -rf 自装目录，占用中可能导致失败）
{ ... }:
{
  vscode.server.enable = true;
}
