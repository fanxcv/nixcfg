# vscode-server 扩展 nix 管理（容器远程开发场景）
# 客户端（mac/nixos）通过 remote-ssh 连入容器时，server 端扩展来自 nix store
# （~/.vscode-server/extensions 链接；vscode-server 本体由客户端自动下载，版本跟客户端走）
# 扩展清单与客户端同源（docs/tsln-vscode.yaml，封装见 modules/home/vscode.nix）
# 注意：扩展由 nix 锁定，客户端侧手动安装扩展会失败；增删扩展 = 改清单 + 重新 nix run .#ide-<机器>
{ ... }:
{
  vscode.server.enable = true;
}
