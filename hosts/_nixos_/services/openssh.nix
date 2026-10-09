# OpenSSH 服务（host key 由 agenix 管理，见 base/keys.nix）
# 密码认证在此关闭：NixOS 的 /etc/ssh/sshd_config 是只读 store 链接，home 层激活改不动
#   （modules/home/ssh.nix 里那段运行时改写对 NixOS 恒失败，故门控跳过），
#   开关必须在 nix 层声明；同理授权公钥也在此声明，首启即生效、不依赖网络拉取。
{ tools, ... }:
let
  # 三台 mac 的用户身份公钥（mini-m4 的即 MacMini；mba-m5 / mbp-m1 共用同一把）。
  # home 层激活仍会拉 GitHub 集合补齐，此处声明的是不依赖网络的保底集合。
  userKeyFiles = [
    "secrets/hosts/mini-m4/ssh-user-key.pub"
    "secrets/hosts/mba-m5/ssh-user-key.pub"
    "secrets/hosts/mbp-m1/ssh-user-key.pub"
  ];
  userKeys = map (path: builtins.readFile (tools.relative path)) userKeyFiles;
in
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

  # root 同集合：与原先「root 可密码登录」等价的可达性，且不再依赖密码
  # （fan 已有 sudo 免密，root 直登不额外扩大权限面）
  users.users.fan.openssh.authorizedKeys.keys = userKeys;
  users.users.root.openssh.authorizedKeys.keys = userKeys;

  # 启用所有 terminfo 以供客户端连接时调用
  environment.enableAllTerminfo = true;
}
