# GUI 桌面应用（NixOS 真机桌面：Plasma + Edge/Bitwarden；容器无头，不经过本平台层）
{ tools, ... }:
{
  imports = tools.scan ./.;
}
