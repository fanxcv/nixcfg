# OPENLIST_TOKEN 环境变量（mini-m4 专属，alist/OpenList 访问凭据）
#   敏感：age 加密管理（secrets/hosts/mini-m4/openlist-token.age，明文在 source/ gitignore），
#   不经 nix 配置/git 明文——与 _common_/secrets.nix 的 AI 密钥机制同型。
#   解密 → ~/.secrets/openlist-token（600）；zsh 启动时读取导出，避免明文落盘配置。
#   如需非 zsh 环境（GUI/launchd）也要此变量，改用 launchctl setenv 或相应位置注入。
{
  pkgs,
  lib,
  ...
}:
{
  home.activation.decryptOpenlistToken = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    umask 077
    ${pkgs.age}/bin/age -d -i "$HOME/.secrets/age-keys.txt" \
      -o "$HOME/.secrets/openlist-token" ${../../..}/secrets/hosts/mini-m4/openlist-token.age
    chmod 600 "$HOME/.secrets/openlist-token"
  '';

  programs.zsh.initContent = lib.mkAfter ''
    # OPENLIST_TOKEN（alist 凭据，age 解密文件；剥离换行）
    export OPENLIST_TOKEN="$(cat "$HOME/.secrets/openlist-token" 2>/dev/null | tr -d '\n')"
  '';
}
