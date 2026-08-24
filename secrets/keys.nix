# agenix 加密接收者（age 公钥）集合——供 secrets/README.md 的加密命令取用
# 私钥：$HOME/.secrets/age-keys.txt（chmod 600；与 ai.env 同目录、同挂载机制，容器重建不丢）
# 新增机器：age-keygen -y ~/.secrets/age-keys.txt 取 pubkey，加到对应 host 下
let
  inherit (builtins) concatLists attrValues;
  # 每台机器/部署单元一个 entry
  hosts = {
    ide = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
    mba-m5 = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
    mbp-m1 = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
    mini-m4 = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
    nix-pve = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
    ds2 = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
    desktop = [
      "age1hn63jj6y5yh2rqhmtw3gdn0887fds7gvjfup7558gvg8vrsatsps7lp204"
    ];
  };
in
{
  hosts = hosts // {
    all = concatLists (attrValues hosts);
  };
  all = concatLists (attrValues hosts);
}
