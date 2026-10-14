# OpenSSH 服务（host key 由 agenix 管理，见 base/keys.nix）
# 密码认证在此关闭：NixOS 的 /etc/ssh/sshd_config 是只读 store 链接，home 层激活改不动
#   （modules/home/ssh.nix 里那段运行时改写对 NixOS 恒失败，故门控跳过），
#   开关必须在 nix 层声明；同理授权公钥也在此声明，首启即生效、不依赖网络拉取。
{ tools, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      ClientAliveInterval = 30;
      ClientAliveCountMax = 10;
      # 密码认证关闭（公钥在上方声明，首启即有可用公钥，不会锁死）
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    hostKeys = [
      {
        path = "/etc/ssh/keys/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # fan 与 root 同集合：持有身份私钥的四台机器（mini-m4 / mba-m5 / mbp-m1 / nix-lenovo）均可登录。
  # 公钥集合见 tools/sshUserKeys.nix；home 层激活仍会拉 GitHub 集合补齐。
  users.users.fan.openssh.authorizedKeys.keys = tools.sshUserKeys.pubKeys;
  users.users.root.openssh.authorizedKeys.keys = tools.sshUserKeys.pubKeys;

  # 启用所有 terminfo 以供客户端连接时调用
  environment.enableAllTerminfo = true;
}
