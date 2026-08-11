# shell 环境：zsh + oh-my-zsh + 定制 fishy 主题
# 对应 alpine-init.sh 的 install_oh_my_zsh()：git clone 方式（不用 Nix 包，可 omz update）
# 镜像开关（对应脚本的 use_proxy="https://gh-proxy.com/"）：
#   useChinaMirror=true（默认）→ 安装/更新地址加 https://gh-proxy.com/ 前缀
#   useChinaMirror=false（fan@ide-global）→ 直连 GitHub 原始地址
# 注意：clone 的 origin 即安装地址，oh-my-zsh 自动更新 / omz update 天然走同一通道

{ pkgs, lib, self, useChinaMirror ? true, ... }:
let
  useProxy = if useChinaMirror then "https://gh-proxy.com/" else "";
  # 安装 + 后期更新的仓库地址（对应脚本 REMOTE=...ohmyzsh.git）
  ohMyZshRepo = useProxy + "https://github.com/ohmyzsh/ohmyzsh.git";
  themeSource = "${self}/home/fan/_common_/themes/fishy.zsh-theme";
in
{
  programs.zsh = {
    enable = true;
    # nix.sh 加载由 HM 接管（Dockerfile 不再写 ~/.zshenv ~/.zshrc，避免 clobber）：
    #   envExtra → ~/.zshenv（zsh 所有模式，含 ssh 远程命令）
    #   initContent 末尾再 source 一次 → ~/.zshrc 双保险（原 Dockerfile 同款语义）
    envExtra = ". /nix/var/nix/profiles/default/etc/profile.d/nix.sh\n";
    initContent = ''
      # ---- oh-my-zsh（git clone 方式，安装/更新见下方 home.activation）----
      plugins=(git zsh-syntax-highlighting zsh-autosuggestions)
      export ZSH="$HOME/.oh-my-zsh"
      export ZSH_CUSTOM="$ZSH/custom"
      source "$ZSH/oh-my-zsh.sh"
      ZSH_THEME="fishy-custom"

      # 常用别名
      alias ll='ls -lah'
      alias la='ls -A'
      alias untar='tar -xzf'

      # nix 双保险（envExtra 已 source 过，此处幂等）
      . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
    '';
  };

  # 对应脚本 install_oh_my_zsh()：
  #   clone oh-my-zsh（origin = ${ohMyZshRepo}）
  #   clone 两个插件到 ZSH_CUSTOM/plugins/（${useProxy}https://github.com/zsh-users/...）
  #   定制主题落到 ZSH_CUSTOM/themes/
  # 已装好则跳过 clone（幂等）；失败只警告不中断 switch
  home.activation.cloneOhMyZsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
      rm -rf "$HOME/.oh-my-zsh"
      ${pkgs.git}/bin/git clone --quiet ${ohMyZshRepo} "$HOME/.oh-my-zsh" \
        || echo "警告: oh-my-zsh clone 失败，下次 switch 重试或手动: git clone ${ohMyZshRepo} ~/.oh-my-zsh"
    fi

    mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
    for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
      if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin/.git" ]; then
        rm -rf "$HOME/.oh-my-zsh/custom/plugins/$plugin"
        ${pkgs.git}/bin/git clone --quiet "${useProxy}https://github.com/zsh-users/$plugin.git" \
          "$HOME/.oh-my-zsh/custom/plugins/$plugin" \
          || echo "警告: 插件 $plugin clone 失败"
      fi
    done

    mkdir -p "$HOME/.oh-my-zsh/custom/themes"
    cp -f ${themeSource} "$HOME/.oh-my-zsh/custom/themes/fishy-custom.zsh-theme"
  '';
}
