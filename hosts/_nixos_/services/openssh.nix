# OpenSSH 服务（host key 由 agenix 管理，见 base/keys.nix）
# 密码认证默认开启（首次接入安全兜底）；home 层 ssh.nix 激活后自动改禁密码 + 拉授权公钥
{ lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      ClientAliveInterval = 30;
      ClientAliveCountMax = 10;
    };
    hostKeys = [
      {
        path = "/etc/ssh/keys/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # 启用所有 terminfo 以供客户端连接时调用
  environment.enableAllTerminfo = true;
}
