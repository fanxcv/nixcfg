# Tailscale 组网（三台 Mac 统一开启）
# 首次使用需 sudo tailscale up 登录一次；之后由 nix 管理服务
{ ... }:
{
  services.tailscale.enable = true;
  # 不覆盖本地 DNS（保持阿里 DNS 生效）
  services.tailscale.overrideLocalDns = false;
}
