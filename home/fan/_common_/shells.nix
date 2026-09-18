# shell 环境：zsh + oh-my-zsh + 定制 fishy 主题
# 对应 alpine-init.sh 的 install_oh_my_zsh()：git clone 方式（不用 Nix 包，可 omz update）
# 镜像/加速开关：统一由 tools/config.nix 集中配置（tools.githubUrl，含 withoutProxy 例外）
#   前缀由 tools/config.nix 的 githubProxy 声明（换代理只改一处 + 跑 scripts/switch-github-proxy.sh 同步 flake inputs）
# 注意：clone 的 origin 即安装地址，oh-my-zsh 自动更新 / omz update 天然走同一通道

{
  pkgs,
  lib,
  self,
  tools,
  config,
  platform ? "container",
  hostName,
  ...
}:
let
  # NixOS 的 nix 由系统 profile 提供（/run/current-system/sw），无 /nix/var/nix/profiles/default；
  # 仅容器/darwin 单用户 nix 需要 source nix.sh 加载 PATH
  nixShSource = lib.optionalString (
    platform != "nixos"
  ) ". /nix/var/nix/profiles/default/etc/profile.d/nix.sh\n";
  # 安装 + 后期更新的仓库地址（对应脚本 REMOTE=...ohmyzsh.git）
  ohMyZshRepo = tools.githubUrl "https://github.com/ohmyzsh/ohmyzsh.git";
  themeSource = "${self}/home/fan/_common_/themes/fishy.zsh-theme";
  # nixcfg 快捷命令（zsh 函数）：进仓库目录 → 完全切到 origin/<分支> → 执行本机部署。
  #   必须显式带分支名：nixcfg main（对齐 origin/main，原 alias 行为）/ nixcfg test（切到 test 分支）。
  #   不传分支名 → 打印用法并拒绝部署（防在本地随意状态下误部署）。
  #   分支名由函数消费，其余参数原样透传给部署命令：nixcfg main --dry-run。
  #   切换语义 = fetch origin <分支> + checkout -B <分支> origin/<分支> + reset --hard origin/<分支>：
  #   丢弃本地未提交改动与该分支未推送 commit，保证部署的就是 origin 最新；
  #   fetch 失败（分支不存在/断网/凭据）即短路，不动本地。
  #   纯 eval（skemate 已改 flake.lock 锁定，不再需要 --impure）。
  #   nixos 仓库固定 /etc/nixos（impermanence 持久化 /persist/etc/nixos）；container/pve 在 root 家目录 ~/nixcfg，无 sudo。
  #   pve 本机自部署走 -- --self（同 pve/self-deploy.sh）。
  repoDir =
    {
      darwin = "$HOME/nixcfg";
      nixos = "/etc/nixos";
      container = "$HOME/nixcfg";
      ubuntu = "$HOME/nixcfg";
      pve = "$HOME/nixcfg";
    }
    .${platform}
    or (throw "shells.nix: 平台 ${platform} 未定义 nixcfg 命令（darwin/nixos/container/ubuntu/pve）");
  deployCmd =
    {
      darwin = "sudo darwin-rebuild switch --flake .#${hostName}";
      nixos = "sudo nixos-rebuild switch --flake /etc/nixos#${hostName}";
      container = "nix run .#${hostName}";
      ubuntu = "nix run .#${hostName}";
      pve = "nix run .#${hostName} -- --self";
    }
    .${platform}
    or (throw "shells.nix: 平台 ${platform} 未定义 nixcfg 命令（darwin/nixos/container/ubuntu/pve）");
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
      # mise 插件随 softwares.mise.enable 门控：装了 mise 的机器才 activate（omz 官方插件，不需 clone）
      plugins=(git zsh-syntax-highlighting zsh-autosuggestions${lib.optionalString config.softwares.mise.enable " mise"})
      export ZSH="$HOME/.oh-my-zsh"
      export ZSH_CUSTOM="$ZSH/custom"
      # 主题必须在 source oh-my-zsh.sh 之前设置，否则加载瞬间仍是默认 robbyrussell
      ZSH_THEME="fishy-custom"
      # nix store 目录（/nix/.../share/zsh）被 compaudit 判为不安全且无法 chmod 持久修复，跳过补全安全检查
      # （仅跳过权限校验与询问，补全正常加载；否则每次开终端都会 y/n 询问）
      export ZSH_DISABLE_COMPFIX="true"
      source "$ZSH/oh-my-zsh.sh"

      # 常用别名（cat/ls/ll 用 bat/eza 增强版，见 global.pkgs）；bat -p = plain（无行号/装饰，
      # 行为与 cat 一致，适合管道/重定向）
      alias cat='bat -p'
      alias ls='eza --icons --group-directories-first'
      alias ll='eza -lah --git --group-directories-first --time-style=long-iso'
      alias la='ls -A'
      alias untar='tar -xzf'

      # nixcfg：切分支 + 部署本机（仓库目录/部署命令见 shells.nix 的 repoDir/deployCmd，按平台分支）
      # 必须显式给分支名，不传拒绝部署：nixcfg main（原行为）| nixcfg test
      # 分支名由函数消费（shift），其余参数透传部署命令：nixcfg main --dry-run
      # unalias：55aa109 之前本命令是 alias，长驻 shell 里残留的同名 alias 会让函数定义
      #   报 "defining function based on alias" parse error 并中断 .zshrc 后续行，故先清再定义。
      unalias nixcfg 2>/dev/null || true
      nixcfg() {
        if [ -z "$1" ]; then
          echo "用法: nixcfg <分支名>   例: nixcfg main / nixcfg test" >&2
          echo "拒绝部署：必须显式指定分支名，避免在本地随意状态下误部署。" >&2
          return 1
        fi
        local branch="$1"
        shift
        cd "${repoDir}" || return 1
        git fetch origin "$branch" || {
          echo "nixcfg: git fetch origin $branch 失败（分支不存在/断网/凭据）" >&2
          return 1
        }
        git checkout -B "$branch" "origin/$branch" || return 1
        git reset --hard "origin/$branch" || return 1
        ${deployCmd} "$@"
      }

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
        ${pkgs.git}/bin/git clone --quiet "${tools.githubUrl "https://github.com/zsh-users/$plugin.git"}" \
          "$HOME/.oh-my-zsh/custom/plugins/$plugin" \
          || echo "警告: 插件 $plugin clone 失败"
      fi
    done

    mkdir -p "$HOME/.oh-my-zsh/custom/themes"
    cp -f ${themeSource} "$HOME/.oh-my-zsh/custom/themes/fishy-custom.zsh-theme"
  '';
}
