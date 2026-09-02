{
  description = "fan 的 Nix 配置仓库（多机共用，结构参考 tsln1998/nixcfg）";

  # 二进制缓存默认走国内镜像；具体列表集中 tools/config.nix。
  # 此处 nixConfig 必须保持静态（flake fetcher 解析阶段读不到 tools），Dockerfile/PVE shell 属跨语言边界，按各自格式手写对齐。
  # 优先级：命令行 --option > 环境变量 NIX_CONFIG > /etc/nix/nix.conf > 这里的 nixConfig
  # 临时跳过：nix run --option substituters https://cache.nixos.org/ ...
  nixConfig = {
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    # 补充 cachix（treefmt-nix / nix-community 等项目的预构建缓存，显著提速）
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # git+https 走 GitHub 加速前缀（国内 GitHub 直连超时）：flakes fetcher 无法配置镜像，URL 前置代理最稳
    # 前缀由 tools/config.nix 的 githubProxy 声明（flake 解析器限制 inputs.url 必须字符串字面量，
    # 换代理：改 tools/config.nix + 跑 scripts/switch-github-proxy.sh 同步 inputs/lock）
    # 稳定版 nixos-26.05：闭包二进制在镜像/官方永久缓存 → 构建命中 USTC/TUNA；
    # 不锁 rev：分支点更新慢（几周一次），nix flake update 自动跟随（升级=全量 nix flake update）
    nixpkgs.url = "git+https://ghfast.top/https://github.com/NixOS/nixpkgs.git?ref=nixos-26.05&shallow=1";
    home-manager = {
      # 与 nixpkgs 26.05 配套的 release 分支（master 要求更新的 nixpkgs）
      url = "git+https://ghfast.top/https://github.com/nix-community/home-manager.git?ref=release-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- unstable 通道：需要新版本的包使用（vscode 本体 + 扩展市场、codex/pi，→ pkgs.repos.unstable）---
    # 锁 rev（flake.lock）+ 周级 nix flake update：unstable 滚动快、二进制保留期短于稳定分支，长时间不更新会掉缓存
    # 命中面压缩到单包：主通道仍走 26.05（见 overlays/unstable.nix 与 modules/home/vscode.nix、home/fan/_common_/{claude,codex,pi}.nix）
    unstable = {
      url = "git+https://ghfast.top/https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable&shallow=1";
    };

    # vscode 扩展补充市场（nixpkgs 缺失的扩展，→ pkgs.repos.vscode.vscode-marketplace-release）
    vscode-extensions = {
      url = "git+https://ghfast.top/https://github.com/nix-community/nix-vscode-extensions.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secrets 加密（agenix）：secrets/*.age 激活时自动解密，见 _common_/secrets.nix 与 secrets/README.md
    agenix = {
      url = "git+https://ghfast.top/https://github.com/ryantm/agenix.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 代码格式化（nix fmt）：nixfmt + statix，配置见 formatter.nix
    treefmt-nix = {
      url = "git+https://ghfast.top/https://github.com/numtide/treefmt-nix.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # git 驱动自动部署：mini-m4 与 nix-pve 已启用（服务器轮询仓库自动切换配置）
    comin = {
      url = "git+https://ghfast.top/https://github.com/nlewo/comin.git?ref=refs/tags/v0.14.0&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      # comin 内部自带的 treefmt-nix 整体跟随（否则它解析 github 旧版 + 旧 nixpkgs，lock 残留双节点）
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    # --- NixOS 真机（nix-pve，PVE 上的虚拟机）：声明式磁盘 / 不可变系统 / Plasma 桌面 ---
    # 注意：input 全部走 gh-proxy（与 nixpkgs/home-manager 一致）；若 gh-proxy 限流导致 lock 拉不动，
    # 可临时用 --override-input 直连 GitHub 或换 ghfast.top 前缀（见下方 URL 格式）
    disko = {
      url = "git+https://ghfast.top/https://github.com/nix-community/disko.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "git+https://ghfast.top/https://github.com/nix-community/impermanence.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Plasma 面板/字体/KWin 声明式定制（home 层，见 home/fan/_nixos_/gui/desktop/plasma/）
    plasma-manager = {
      url = "git+https://ghfast.top/https://github.com/nix-community/plasma-manager.git?ref=trunk&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Catppuccin 全家桶主题模块（plasma/sddm/grub/plymouth/fcitx5 等 target，见 themes/catppuccin.nix）
    # 固定 rev（同 tsln1998/nixcfg，release-26.11 前的稳定点）；nixpkgs 跟随避免双实例
    catppuccin = {
      url = "git+https://ghfast.top/https://github.com/catppuccin/nix.git?ref=main&rev=9e84aa294455c58a1caba475902d06c1170ed5c1&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # skemate（自研终端复用服务）官方二进制分发：skemate 仓库（hc-git.qksxin.com/wangyu/skemate）
    # 自带 flake.nix，读仓库内提交的 latest.json（version/url/sha256 快照）产出 packages.<system>.skemate。
    # ref=deploy：发版流程在 deploy 分支（make release → 版本化目录推 CDN + 更新 latest.json → push deploy），
    # main 不更新 latest.json，故必须锁 deploy 分支。
    # flake.lock 锁 git rev：升级 = nix flake update skemate（rev 变必重拉，无 fetcher-cache 缓存坑），
    # 纯 eval 无需 --impure；nixpkgs 跟随本仓库避免双节点。
    skemate = {
      url = "git+https://hc-git.qksxin.com/wangyu/skemate.git?ref=deploy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- macOS（nix-darwin）：三台 Mac 的系统层，见 hosts/_darwin_/ 与 hosts/<host>/ ---
    # nix-darwin 用配套分支：nix-darwin-26.05 ↔ nixpkgs-26.05-darwin（checkRelease 强制匹配）
    nixpkgs-darwin = {
      # darwin 专属 channel（闭包含完整 darwin 构建，镜像同步）；不锁 rev，跟随分支
      url = "git+https://ghfast.top/https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-26.05-darwin&shallow=1";
    };
    nix-darwin = {
      url = "git+https://ghfast.top/https://github.com/nix-darwin/nix-darwin.git?ref=nix-darwin-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # homebrew 声明式管理（casks 清单见 hosts/_darwin_/base/apps.nix）
    nix-homebrew = {
      url = "git+https://ghfast.top/https://github.com/zhaofengli/nix-homebrew.git?ref=main&shallow=1";
      inputs.brew-src.follows = "homebrew";
    };
    homebrew = {
      url = "git+https://ghfast.top/https://github.com/Homebrew/brew.git?ref=main&shallow=1";
      flake = false;
    };
    homebrew-core = {
      url = "git+https://ghfast.top/https://github.com/homebrew/homebrew-core.git?ref=main&shallow=1";
      flake = false;
    };
    homebrew-cask = {
      url = "git+https://ghfast.top/https://github.com/homebrew/homebrew-cask.git?ref=main&shallow=1";
      flake = false;
    };
    # tart 等公式的 tap（mini-m4 的 hosts/mini-m4/homebrew.nix 声明）
    cirruslabs-cli = {
      url = "git+https://ghfast.top/https://github.com/cirruslabs/homebrew-cli.git?ref=master&shallow=1";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      treefmt-nix,
      comin,
      nix-darwin,
      ...
    }@inputs:
    let
      # outputs == self（flake 自身），模块里统一用这个引用
      outputs = self;
      lib = nixpkgs.lib;
      # 目录扫描/相对路径工具（模块自动导入，见 tools/scan.nix、tools/relative.nix）
      tools = import ./tools { inherit lib self; };
      # 全局镜像/代理集中配置（tools/config.nix，唯一配置入口）—— useChinaMirror 注入默认值取自这里
      netConfig = tools.config;
      # skemate（自研终端复用服务）官方二进制分发，定义见 overlays/skemate.nix
      # flake.lock 锁定 skemate 仓库 rev（input 声明见上方 inputs.skemate，升级 nix flake update skemate）
      skemateOverlay = import ./overlays/skemate.nix inputs;
      # unstable/vscode 市场 overlay（pkgs.repos.unstable / pkgs.repos.vscode，定义见 overlays/）
      # unstable 服务包：vscode 本体（nixos）+ 扩展市场（mac/nixos）+ codex/pi（_common_）
      unstableOverlay = import ./overlays/unstable.nix { inherit inputs; };
      vscodeOverlay = import ./overlays/vscode.nix { inherit inputs; };
      # comin 包共享构建（消除 nixos/mini-m4 两处 buildGoModule 重复，见 overlays/comin.nix）
      cominOverlay = import ./overlays/comin.nix { inherit lib inputs; };
      # 本地包统一注入，供所有配置构造器复用
      localPkgsOverlay =
        final: prev:
        import ./packages {
          pkgs = prev;
          githubFetchBase = tools.githubFetchBase;
        };
      # unfree 白名单：vscode 本体/扩展（unstable 通道，见 modules/home/vscode.nix；
      # pylance 为微软专有 license，remote-ssh 同理）
      unfreeAllowlist = [
        "vscode"
        "vscode-extension-ms-vscode-remote-remote-ssh"
        "vscode-extension-MS-python-vscode-pylance"
        "vscode-extension-ms-ceintl-vscode-language-pack-zh-hans"
        "vscode-extension-mhutchie-git-graph"
      ];
      # 统一构造 pkgs；通道与额外 unfree 差异由调用点显式传入
      mkPkgs =
        {
          system,
          nixpkgsInput,
          extraUnfree ? [ ],
        }:
        import nixpkgsInput {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) (unfreeAllowlist ++ extraUnfree);
          overlays = [
            skemateOverlay
            unstableOverlay
            vscodeOverlay
            cominOverlay
            localPkgsOverlay
          ];
        };
      # 每个 system 生成一套可运行包（nix run 一步 build+activate）
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      # 生成指定机器上的 home 配置（模块清单由 home/fan/module-list.nix 统一组装）
      #   hostName:        机器名（容器 hostname 由部署层 docker-compose 决定，与此无关）
      #                     home/fan/<hostName>/ 目录可选：存在则注入机器微调，不存在自动跳过
      #   system:          架构（aarch64-linux / x86_64-linux / aarch64-darwin）
      #   platform:        平台（nixos=NixOS真机 / ubuntu=Ubuntu服务器真机 / container=容器（继承 ubuntu）/ alpine=Alpine服务器 / darwin=macOS，
      #                     注入 home/fan/_nixos_ 或 _ubuntu_ 或 _container_ 或 _alpine_ 或 _darwin_）
      #   useChinaMirror:  是否走国内镜像（false 时 mise 等直连官方源）
      #   isContainer:     是否容器环境（容器里 docker daemon 起不来，不安装 docker 全家桶；
      #                     容器用户覆盖为 root，见 _common_/container.nix）
      mkHomeConfig =
        {
          hostName,
          system ? "aarch64-linux",
          platform ? "nixos",
          useChinaMirror ? netConfig.useChinaMirror,
          isContainer ? false,
          extraUnfree ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs {
            inherit system;
            nixpkgsInput = nixpkgs;
            inherit extraUnfree;
          };
          modules = [
            ./home/fan
          ]
          ++ import ./home/fan/module-list.nix {
            inherit
              lib
              self
              platform
              hostName
              ;
          };
          extraSpecialArgs = {
            inherit
              self
              inputs
              outputs
              tools
              useChinaMirror
              hostName
              isContainer
              platform
              ;
          };
        };
      # 生成指定 macOS 机器的 nix-darwin 配置（home-manager 内嵌，darwin-rebuild 一次管全部）
      #   系统层：hosts/<hostName>/default.nix 组装（见 hosts/README.md）
      #   用户层：users/fan 复用 home/fan/module-list.nix，注入公共/平台/可选机器层
      mkDarwinConfig =
        {
          hostName,
          system ? "aarch64-darwin",
        }:
        nix-darwin.lib.darwinSystem {
          inherit system;
          # mac 用 nixpkgs-26.05-darwin channel（darwin 闭包完整，镜像命中）；与 nix-darwin-26.05 分支配套
          pkgs = mkPkgs {
            inherit system;
            nixpkgsInput = inputs."nixpkgs-darwin";
          };
          modules = [
            ./hosts/${hostName}
            {
              networking.hostName = hostName;
            }
          ];
          specialArgs = {
            inherit
              self
              inputs
              outputs
              tools
              ;
            # darwin 固定值（与 mkHomeConfig 的注入对齐，home 层模块统一取用；默认取集中配置 tools/config.nix）
            useChinaMirror = netConfig.useChinaMirror;
            isContainer = false;
            platform = "darwin";
          };
        };
    in
    {
      # --- 自建模块库（tsln 思路）：平台 base 层引用 ---
      # darwin 系统层：hosts/_darwin_/base → modules/darwin（nix 配置等）
      # nixos 系统层：hosts/_nixos_/base → modules/nixos（当前空）
      # home 用户层：home/fan/_common_ → modules/home（vscode 封装等；容器同吃但默认关闭）
      nixosModules.default = import ./modules/nixos;
      darwinModules.default = import ./modules/darwin;
      homeModules.default = import ./modules/home;

      homeConfigurations = {
        # Docker 开发容器（Ubuntu，ide-si / ide-lenovo）：容器里 docker daemon 跑不起来，isContainer=true 跳过 docker 安装
        # 代理：仅 ide-si 走（sysenv.nix 接管环境变量+hosts，与 compose 无关）；lenovo 国内直连
        # 机器专属：mise 组件共享 _container_/mise.nix（hostName 分支差异），容器内 nix run .#ide-si / .#ide-lenovo
        # 容器平台层（_container_，继承 _ubuntu_ 系统基础）：Ubuntu 层留给服务器/真机，_nixos_ 仅 NixOS 真机
        "fan@ide-si" = mkHomeConfig {
          hostName = "ide-si";
          platform = "container";
          isContainer = true;
        };
        "fan@ide-lenovo" = mkHomeConfig {
          hostName = "ide-lenovo";
          platform = "container";
          isContainer = true;
          extraUnfree = [
            "microsoft-edge"
            "albert"
          ];
        };

        # --- 多台 ide 开发容器：一行注册即可（机器目录可选），hostname 在部署层 docker-compose 里设 ---
        # "fan@ide-eu" = mkHomeConfig { hostName = "ide-eu"; isContainer = true; };
        # "fan@ide-us" = mkHomeConfig { hostName = "ide-us"; isContainer = true; };

        # --- 云服务器（Ubuntu 底，B 路线：系统层归发行版，nix 管用户态）---
        # 部署：nix run .#ali-ai（服务器上仓库副本 + USER=root 激活）
        "root@ali-ai" = mkHomeConfig {
          hostName = "ali-ai";
          system = "x86_64-linux";
          platform = "ubuntu";
        };

        # --- 以后加真机：一行注册 + 对应目录，例如 ---
        # "fan@macbook" = mkHomeConfig { hostName = "macbook"; system = "aarch64-darwin"; platform = "darwin"; };
        # "fan@laptop"  = mkHomeConfig { hostName = "laptop"; system = "x86_64-linux"; };

        # --- PVE 宿主机（Debian 底，非 NixOS）：用户层 HM standalone（root），系统层见 pve/（渲染+推送）---
        # 部署：nix run .#ds2 / .#desktop（bootstrap nix → nix copy → 系统层 apply，见 pve/deploy.nix）
        "fan@ds2" = mkHomeConfig {
          hostName = "ds2";
          system = "x86_64-linux";
          platform = "pve";
        };
        "fan@desktop" = mkHomeConfig {
          hostName = "desktop";
          system = "x86_64-linux";
          platform = "pve";
        };
        "fan@fan" = mkHomeConfig {
          hostName = "fan";
          system = "x86_64-linux";
          platform = "pve";
        };
        "fan@hp" = mkHomeConfig {
          hostName = "hp";
          system = "x86_64-linux";
          platform = "pve";
        };
        "fan@mi" = mkHomeConfig {
          hostName = "mi";
          system = "x86_64-linux";
          platform = "pve";
        };
        "fan@razer" = mkHomeConfig {
          hostName = "razer";
          system = "x86_64-linux";
          platform = "pve";
        };
      };

      # --- macOS：三台 nix-darwin（home-manager 内嵌，darwin-rebuild switch --flake .#<机器>）---
      # 系统层组装见 hosts/<host>/default.nix；用户层按 home/fan/module-list.nix 自动组装
      darwinConfigurations = {
        mba-m5 = mkDarwinConfig { hostName = "mba-m5"; };
        mbp-m1 = mkDarwinConfig { hostName = "mbp-m1"; };
        mini-m4 = mkDarwinConfig { hostName = "mini-m4"; };
      };

      # --- NixOS 真机：nix-pve（Proxmox VE 上的虚拟机，128G 盘 + KDE Plasma 桌面）---
      # 系统层：hosts/nix-pve/default.nix（disko 分区 / impermanence 持久化 / Plasma 桌面）
      # 用户层：users/fan 复用 home/fan/module-list.nix（_common_ + _nixos_ + 可选 nix-pve 差异）
      # 部署：nixos-rebuild switch --flake .#nix-pve；comin 已启用，轮询 main 自动部署
      nixosConfigurations.nix-pve = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # 与 mkHomeConfig 同款 pkgs：overlay 注入 + unfree 放行（unfreeAllowlist + microsoft-edge / libsciter[clash-verge-rev]）
        # 本地包（packages/，catppuccin-konsole 等）以 overlay 并入（home 层 useGlobalPkgs 直接用）
        pkgs = mkPkgs {
          system = "x86_64-linux";
          nixpkgsInput = nixpkgs;
          extraUnfree = [
            "microsoft-edge"
            "libsciter"
          ];
        };
        modules = [ ./hosts/nix-pve ];
        specialArgs = {
          inherit
            self
            inputs
            outputs
            tools
            ;
          useChinaMirror = netConfig.useChinaMirror;
          isContainer = false;
          platform = "nixos";
        };
      };

      # --- NixOS 真机：nix-book（无界14S 笔记本，476.9G NVMe + AMD 7840HS/780M + KDE Plasma 桌面）---
      # 系统层：hosts/nix-book/default.nix（disko 分区 / impermanence 持久化 / Plasma 桌面 / Wayland）
      # 用户层：users/fan 复用 home/fan/module-list.nix（_common_ + _nixos_ + 可选 nix-book 差异）
      # 部署：nixos-rebuild switch --flake .#nix-book（手动，无 comin）
      nixosConfigurations.nix-book = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # 与 mkHomeConfig 同款 pkgs：overlay 注入 + unfree 放行（unfreeAllowlist + microsoft-edge / libsciter[clash-verge-rev] / wechat / qq）
        # 本地包（packages/，catppuccin-konsole 等）以 overlay 并入（home 层 useGlobalPkgs 直接用）
        pkgs = mkPkgs {
          system = "x86_64-linux";
          nixpkgsInput = nixpkgs;
          extraUnfree = [
            "microsoft-edge"
            "libsciter"
            "wechat"
            "qq"
          ];
        };
        modules = [ ./hosts/nix-book ];
        specialArgs = {
          inherit
            self
            inputs
            outputs
            tools
            ;
          useChinaMirror = netConfig.useChinaMirror;
          isContainer = false;
          platform = "nixos";
        };
      };

      # --- 简短命令别名：nix build .#<机器名> && ./result/activate（两步）---
      # homeConfigurations 标准名保留（兼容 home-manager switch --flake 等工具）

      # --- 一步到位：nix run .#<机器名>（构建 + activate 一条命令）---
      # ide 容器可能跑在不同架构服务器（lenovo/si-11 等），激活配置必须按当前 system 构建：
      # 不能引用固定架构的 homeConfigurations（会 platform mismatch，如 x86_64 机器拿到 aarch64 配置）
      # 容器只跑 linux：darwin 宿主上构建容器配置会 hostPlatform.isDarwin 误判（见 modules/home/ssh.nix 门控），
      # 故 ide 别名仅对 linux 系统生成；本地包（packages/）仍全平台可用
      # 本地包集合（packages/ 目录）与机器别名合并导出：nix build .#<包名> 或 nix run .#<机器名>
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          isLinux = builtins.elem system [
            "x86_64-linux"
            "aarch64-linux"
          ];
        in
        (import ./packages {
          inherit pkgs;
          githubFetchBase = tools.githubFetchBase;
        })
        // lib.optionalAttrs isLinux {
          # 机器专属别名：mise 组件共享 _container_/mise.nix（hostName 分支差异），si/lenovo 各一份
          # HOME_MANAGER_BACKUP_EXT=backup：已存在的手配文件（如 .codex/config.toml）自动备份为 .backup 再覆盖
          ide-si = pkgs.writeShellScriptBin "ide-activate" "export USER=root; export HOME_MANAGER_BACKUP_EXT=backup; exec ${
            (mkHomeConfig {
              hostName = "ide-si";
              inherit system;
              platform = "container";
              isContainer = true;
            }).activationPackage
          }/activate";
          ide-lenovo = pkgs.writeShellScriptBin "ide-activate" "export USER=root; export HOME_MANAGER_BACKUP_EXT=backup; exec ${
            (mkHomeConfig {
              hostName = "ide-lenovo";
              inherit system;
              platform = "container";
              isContainer = true;
              extraUnfree = [
                "microsoft-edge"
                "albert"
              ];
            }).activationPackage
          }/activate";
          # 云服务器（ali-ai）：服务器上仓库副本 + nix run .#ali-ai（USER=root 激活，同 ide 模式）
          ali-ai = pkgs.writeShellScriptBin "ali-ai-activate" "export USER=root; export HOME_MANAGER_BACKUP_EXT=backup; exec ${
            (mkHomeConfig {
              hostName = "ali-ai";
              inherit system;
              platform = "ubuntu";
            }).activationPackage
          }/activate";
          # PVE 宿主机部署（ds2 / desktop）：bootstrap nix → 推 git 凭据 + clone 仓库 → 远程构建 HM + activate → 系统层 apply
          # （apt 源/DNS/去 nag/pve-assist，见 pve/ 目录；host 参数决定机器层）
          ds2 = import ./pve/deploy.nix {
            inherit pkgs lib;
            host = "ds2";
          };
          desktop = import ./pve/deploy.nix {
            inherit pkgs lib;
            host = "desktop";
          };
          fan = import ./pve/deploy.nix {
            inherit pkgs lib;
            host = "fan";
          };
          hp = import ./pve/deploy.nix {
            inherit pkgs lib;
            host = "hp";
          };
          mi = import ./pve/deploy.nix {
            inherit pkgs lib;
            host = "mi";
          };
          razer = import ./pve/deploy.nix {
            inherit pkgs lib;
            host = "razer";
          };
        }
        // lib.optionalAttrs (!isLinux) {
          # Mac 一次性构建+激活别名：nix run .#mba-m5 等（activate 必须 root，内置 sudo）
          "mba-m5" =
            pkgs.writeShellScriptBin "mba-m5" "exec sudo ${self.darwinConfigurations.mba-m5.system}/activate";
          "mbp-m1" =
            pkgs.writeShellScriptBin "mbp-m1" "exec sudo ${self.darwinConfigurations.mbp-m1.system}/activate";
          "mini-m4" =
            pkgs.writeShellScriptBin "mini-m4" "exec sudo ${self.darwinConfigurations.mini-m4.system}/activate";
        }
      );

      # --- 多台 ide 部署的别名同规则：nix build .#ide-si / .#ide-lenovo（packages 块内各一行）---

      # 代码格式化：nix fmt 一键格式化（treefmt：nixfmt + statix，配置见 formatter.nix）
      formatter = forAllSystems (
        system:
        (treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./formatter.nix).config.build.wrapper
      );

      # 格式与回归检查：nix flake check（本地/CI 均可用）
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          formatting = (treefmt-nix.lib.evalModule pkgs ./formatter.nix).config.build.check self;
          rustdesk-injector = pkgs.runCommand "rustdesk-injector-test" { } ''
            ${pkgs.python3}/bin/python3 ${./tests/rustdesk-injector.py} ${./tools/rustdesk-inject.py}
            touch "$out"
          '';
        }
      );
    };
}
