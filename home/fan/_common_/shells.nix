# shell 环境：zsh + oh-my-zsh + 定制 fishy 主题
# 对应 alpine-init.sh 的 install_oh_my_zsh()：git clone 方式（不用 Nix 包，可 omz update）
# 镜像开关（对应脚本的 use_proxy="${tools.githubProxy}"）：
#   useChinaMirror=true（默认，所有 ide 容器）→ 安装/更新地址加 GitHub 加速前缀
#   useChinaMirror=false（NixOS 真机国外直连场景）→ 直连 GitHub 原始地址
#   前缀由 tools/github-proxy.nix 集中管理（换代理只改一处 + 跑 scripts/switch-github-proxy.sh）
# 注意：clone 的 origin 即安装地址，oh-my-zsh 自动更新 / omz update 天然走同一通道

{ pkgs, lib, self, tools ? { githubProxy = "https://ghfast.top/"; }, platform ? "container", useChinaMirror ? true, ... }:
let
  useProxy = if useChinaMirror then tools.githubProxy else "";
  # NixOS 的 nix 由系统 profile 提供（/run/current-system/sw），无 /nix/var/nix/profiles/default；
  # 仅容器/darwin 单用户 nix 需要 source nix.sh 加载 PATH
  nixShSource = lib.optionalString (platform != "nixos") ". /nix/var/nix/profiles/default/etc/profile.d/nix.sh\n";
  # 安装 + 后期更新的仓库地址（对应脚本 REMOTE=...ohmyzsh.git）
  ohMyZshRepo = useProxy + "https://github.com/ohmyzsh/ohmyzsh.git";
  themeSource = "${self}/home/fan/_common_/themes/fishy.zsh-theme";
in
{
  programs.zsh = {
    enable = true;
    # HM 模板自带 compinit（无 -u）遇 nix store 不安全目录（owner=admin，compaudit 误判）会 y/n 询问；
    # omz 已接管 compinit（ZSH_DISABLE_COMPFIX=true → compinit -u 不询问），此处关闭 HM 自带的避免重复调用
    enableCompletion = false;
    # nix.sh 加载由 HM 接管（Dockerfile 不再写 ~/.zshenv ~/.zshrc，避免 clobber）：
    #   envExtra → ~/.zshenv（zsh 所有模式，含 ssh 远程命令）
    #   initContent 末尾再 source 一次 → ~/.zshrc 双保险（原 Dockerfile 同款语义）
    envExtra = nixShSource;
    initContent = ''
      # ---- oh-my-zsh（git clone 方式，安装/更新见下方 home.activation）----
      plugins=(git zsh-syntax-highlighting zsh-autosuggestions mise)
      export ZSH="$HOME/.oh-my-zsh"
      export ZSH_CUSTOM="$ZSH/custom"
      # 主题必须在 source oh-my-zsh.sh 之前设置，否则加载瞬间仍是默认 robbyrussell
      ZSH_THEME="fishy-custom"
      # nix store 目录（/nix/.../share/zsh）被 compaudit 判为不安全且无法 chmod 持久修复，跳过补全安全检查
      # （仅跳过权限校验与询问，补全正常加载；否则每次开终端都会 y/n 询问）
      export ZSH_DISABLE_COMPFIX="true"
      source "$ZSH/oh-my-zsh.sh"

      # 常用别名
      alias ll='ls -lah'
      alias la='ls -A'
      alias untar='tar -xzf'

      # nix 双保险（envExtra 已 source 过，此处幂等；NixOS 无该路径，跳过）
      ${lib.optionalString (platform != "nixos") ". /nix/var/nix/profiles/default/etc/profile.d/nix.sh"}
    '';
  };

  # 对应脚本 install_oh_my_zsh()：
  #   clone oh-my-zsh（origin = ${ohMyZshRepo}）
  #   clone 两个插件到 ZSH_CUSTOM/plugins/（${useProxy}https://github.com/zsh-users/...）
  #   定制主题落到 ZSH_CUSTOM/themes/
  # 已装好则跳过 clone（幂等）；失败只警告不中断 switch
  home.activation.cloneOhMyZsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
      # .oh-my-zsh 在 NixOS 真机是 /persist 的 bind mount（home.persistence），
      # rm 挂载点会报 Device busy（激活环境无 mountpoint 命令，统一用 find -delete 清内容）
      find "$HOME/.oh-my-zsh" -mindepth 1 -delete 2>/dev/null || true
      ${pkgs.git}/bin/git clone --quiet ${ohMyZshRepo} "$HOME/.oh-my-zsh" \
        || echo "警告: oh-my-zsh clone 失败，下次 switch 重试或手动: git clone ${ohMyZshRepo} ~/.oh-my-zsh"
    fi

    mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
    for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
      if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin/.git" ]; then
        find "$HOME/.oh-my-zsh/custom/plugins/$plugin" -mindepth 1 -delete 2>/dev/null || true
        ${pkgs.git}/bin/git clone --quiet "${useProxy}https://github.com/zsh-users/$plugin.git" \
          "$HOME/.oh-my-zsh/custom/plugins/$plugin" \
          || echo "警告: 插件 $plugin clone 失败"
      fi
    done

    mkdir -p "$HOME/.oh-my-zsh/custom/themes"
    cp -f ${themeSource} "$HOME/.oh-my-zsh/custom/themes/fishy-custom.zsh-theme"
  '';
}
