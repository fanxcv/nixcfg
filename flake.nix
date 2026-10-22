{
  description = "fan 的 Nix 配置仓库（多机共用，结构参考 tsln1998/nixcfg）";

  # 二进制缓存默认走国内镜像；具体列表集中 tools/config.nix。
  # 此处 nixConfig 必须保持静态（flake fetcher 解析阶段读不到 tools），Dockerfile/PVE shell 属跨语言边界，按各自格式手写对齐。
  # 优先级：命令行 --option > 环境变量 NIX_CONFIG > /etc/nix/nix.conf > 这里的 nixConfig
  # 临时跳过：nix run --option substituters https://cache.nixos.org/ ...
  nixConfig = {
    substituters = [
      "https://mirrors.cernet.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    # 补充 cachix（treefmt-nix / nix-community 等项目的预构建缓存，显著提速）
    extra-substituters = [
      "https://cache.numtide.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    # git+https 走 GitHub 加速前缀（国内 GitHub 直连超时）：flakes fetcher 无法配置镜像，URL 前置代理最稳
    # 前缀由 tools/config.nix 的 githubProxy 声明（flake 解析器限制 inputs.url 必须字符串字面量，
    # 换代理：改 tools/config.nix + 跑 scripts/switch-github-proxy.sh 同步 inputs/lock）
    # 稳定版 nixos-26.05：闭包二进制在镜像/官方永久缓存 → 构建命中 CERNET 镜像；
    # 不锁 rev：分支点更新慢（几周一次），nix flake update 自动跟随（升级=全量 nix flake update）
    nixpkgs.url = "git+https://ghfast.top/https://github.com/NixOS/nixpkgs.git?ref=nixos-26.05&shallow=1";
    home-manager = {
      # 与 nixpkgs 26.05 配套的 release 分支（master 要求更新的 nixpkgs）
      url = "git+https://ghfast.top/https://github.com/nix-community/home-manager.git?ref=release-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # --- unstable 通道：需要新版本的包使用（vscode 本体、codex，→ pkgs.repos.unstable）---
    # 锁 rev（flake.lock）+ 周级 nix flake update：unstable 滚动快、二进制保留期短于稳定分支，长时间不更新会掉缓存
    # 命中面压缩到单包：主通道仍走 26.05（见 overlays/unstable.nix 与 modules/home/vscode.nix、modules/home/{codex,pi}.nix）
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

    # --- NixOS 真机：声明式磁盘 / 不可变系统 / Plasma 桌面 ---
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
    # 跟随 main（不再锁 rev）；nixpkgs 跟随避免双实例
    catppuccin = {
      url = "git+https://ghfast.top/https://github.com/catppuccin/nix.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # skemate（自研终端复用服务）官方二进制分发：skemate 仓库（hc-git.qksxin.com/wangyu/skemate）
    # 自带 flake.nix，读仓库内提交的 latest.json（version/url/sha256 快照）产出 packages.<system>.skemate。
    # ref=deploy：发版流程在 deploy 分支（make release → 版本化目录推 CDN + 更新 latest.json → push deploy），
    # main 不更新 latest.json，故必须锁 deploy 分支。
    # flake.lock 锁 git rev：升级 = nix flake update skemate（rev 变必重拉，无 fetcher-cache 缓存坑），
    # 纯 eval 无需 --impure；nixpkgs 跟随本仓库避免双节点。
    skemate = {
      # token 内嵌 URL：免 git 交互式询问账号密码（hc-git 私有仓库）
      url = "git+https://f0618ffdd3f4325a4ac55dfd47c4f9c62dfcecf2@hc-git.qksxin.com/wangyu/skemate.git?ref=deploy";
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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      agenix,
      treefmt-nix,
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
      # 机器注册表（单一事实来源，见 tools/machines.nix）：三大配置族与 packages 别名由此派生
      machines = import ./tools/machines.nix;
      # 按 kind 取机器（kind 同时是 home 层 platform 取值）
      machinesOfKind = kinds: lib.filterAttrs (n: m: builtins.elem m.kind kinds) machines;
      # 带 nix run .#<机名> 别名的机器，按 kind 取
      aliasMachinesOfKind = kinds: lib.filterAttrs (n: m: m.alias) (machinesOfKind kinds);
      # skemate（自研终端复用服务）官方二进制分发，定义见 overlays/skemate.nix
      # flake.lock 锁定 skemate 仓库 rev（input 声明见上方 inputs.skemate，升级 nix flake update skemate）
      skemateOverlay = import ./overlays/skemate.nix inputs;
      # unstable/vscode 市场 overlay（pkgs.repos.unstable / pkgs.repos.vscode，定义见 overlays/）
      # unstable 服务包：vscode 本体（nixos）+ 扩展市场（mac/nixos）+ codex/pi（_common_）
      unstableOverlay = import ./overlays/unstable.nix { inherit inputs; };
      vscodeOverlay = import ./overlays/vscode.nix { inherit inputs; };
      # Konsole 隐藏工具栏（--hide-toolbars 包装，见 overlays/konsole.nix）
      konsoleOverlay = import ./overlays/konsole.nix lib;
      # 本地包统一注入，供所有配置构造器复用
      localPkgsOverlay =
        final: prev:
        import ./packages {
          pkgs = prev;
          githubFetchBase = tools.githubFetchBase;
        };
      # unfree 白名单：vscode 本体 + 扩展（扩展名由 modules/home/vscode-extensions.nix 的 unfree 字段生成，
      # 加插件只改该清单；该文件是 home 模块，清单经 _module.args 暴露，import 直读静态字段不需 pkgs；
      # pylance 为微软专有 license，remote-ssh 同理）+ tart
      unfreeAllowlist = [
        "vscode"
      ]
      ++ map (r: r.unfree) (
        builtins.filter (r: r ? unfree)
          (import ./modules/home/vscode-extensions.nix)._module.args.vscodeExtensionManifest
      )
      ++ [ "tart" ]; # macOS 虚拟机（fsl11Asl20，nixpkgs 原生，mini-m4）
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
            konsoleOverlay
            localPkgsOverlay
          ];
        };
      # 全部目标架构（checks 与 packages 共用）
      allSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      # 每个 system 生成一套可运行包（nix run 一步 build+activate）
      forAllSystems = lib.genAttrs allSystems;
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
      #   系统层：hosts/_darwin_/ 组装公共部分 + hosts/<hostName>/ 机器差异（见 hosts/README.md）
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
            ./hosts/_darwin_
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
      # 生成 NixOS 真机配置（系统层 hosts/<hostName>；用户层 users/fan 复用 home/fan/module-list.nix）
      mkNixosConfig =
        {
          hostName,
          system ? "x86_64-linux",
          extraUnfree ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          pkgs = mkPkgs {
            inherit system;
            nixpkgsInput = nixpkgs;
            inherit extraUnfree;
          };
          modules = [ ./hosts/${hostName} ];
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
    in
    {
      # --- 自建模块库（tsln 思路）：平台 base 层引用 ---
      # darwin 系统层：hosts/_darwin_/base → modules/darwin（nix 配置等）
      # nixos 系统层：hosts/_nixos_/base → modules/nixos（当前空）
      # home 用户层：home/fan/_common_ → modules/home（vscode 封装等；容器同吃但默认关闭）
      nixosModules.default = import ./modules/nixos;
      darwinModules.default = import ./modules/darwin;
      homeModules.default = import ./modules/home;

      # homeConfigurations（standalone HM：容器 / ubuntu / pve）由 registry 派生，键 = "<user>@<机名>"
      # 容器：isContainer=true 跳过 docker 安装（容器里 daemon 起不来）；容器平台层 _container_ 继承 _ubuntu_，_nixos_ 仅 NixOS 真机
      # 代理：仅 ide-si 走（sysenv.nix 接管环境变量，与 compose 无关）；内网 hosts 三台共用（_container_/extra-hosts.nix）
      # 机器专属：mise 组件共享 _container_/mise.nix（hostName 分支差异）；ide-mac 桌面走 KasmVNC arm64 + chromium 替代 google-chrome
      homeConfigurations =
        lib.mapAttrs'
          (
            hostName: m:
            lib.nameValuePair "${m.user}@${hostName}" (mkHomeConfig {
              inherit hostName;
              inherit (m) system;
              platform = m.kind;
              isContainer = m.kind == "container";
              extraUnfree = m.extraUnfree or [ ];
            })
          )
          (machinesOfKind [
            "container"
            "ubuntu"
            "pve"
          ]);

      # --- macOS：三台 nix-darwin（home-manager 内嵌，darwin-rebuild switch --flake .#<机器>）---
      # 系统层组装见 hosts/_darwin_/default.nix（公共）+ hosts/<host>/default.nix（差异）；
      # 用户层按 home/fan/module-list.nix 自动组装
      darwinConfigurations = lib.mapAttrs (
        hostName: m:
        mkDarwinConfig {
          inherit hostName;
          inherit (m) system;
        }
      ) (machinesOfKind [ "darwin" ]);

      # --- NixOS 真机（nix-lenovo / nix-asus）由 registry 派生 ---
      # 系统层：hosts/<机>/default.nix（disko 分区 / impermanence 持久化 / Plasma 桌面）
      # 用户层：users/fan 复用 home/fan/module-list.nix（_common_ + _nixos_ + 可选机器差异）
      # 部署：nixos-rebuild switch --flake .#<机>（本仓库无自动部署）
      nixosConfigurations = lib.mapAttrs (
        hostName: m:
        mkNixosConfig {
          inherit hostName;
          inherit (m) system;
          extraUnfree = m.extraUnfree or [ ];
        }
      ) (machinesOfKind [ "nixos" ]);

      # --- 一步到位：nix run .#<机器名>（构建 + activate 一条命令）---
      # homeConfigurations 标准名保留（兼容 home-manager switch --flake 等工具）
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
          # 机器别名构造器：nix run .#<机器> 一步构建+激活（消除 homeConfigurations 与 packages 的重复构造）
          mkHomeAlias =
            {
              hostName,
              system,
              platform,
              isContainer ? false,
              extraUnfree ? [ ],
            }:
            pkgs.writeShellScriptBin "${hostName}-activate" ''
              export USER=root
              export HOME_MANAGER_BACKUP_EXT=backup
              exec ${
                (mkHomeConfig {
                  inherit
                    hostName
                    system
                    platform
                    isContainer
                    extraUnfree
                    ;
                }).activationPackage
              }/activate
            '';
        in
        (import ./packages {
          inherit pkgs;
          githubFetchBase = tools.githubFetchBase;
        })
        // lib.optionalAttrs isLinux (
          # 容器/ubuntu 机器别名：HOME_MANAGER_BACKUP_EXT=backup 备份已存在的手配文件（如 .codex/config.toml）
          # 机器专属：mise 组件共享 _container_/mise.nix（hostName 分支差异）
          lib.mapAttrs
            (
              hostName: m:
              mkHomeAlias {
                inherit hostName system;
                platform = m.kind;
                isContainer = m.kind == "container";
                extraUnfree = m.extraUnfree or [ ];
              }
            )
            (aliasMachinesOfKind [
              "container"
              "ubuntu"
            ])
          # PVE 宿主机部署：bootstrap nix → 推 git 凭据 + clone 仓库 → 远程构建 HM + activate → 系统层 apply
          # （apt 源/DNS/去 nag/pve-assist，见 pve/ 目录；host 参数决定机器层）
          // lib.mapAttrs (host: _: import ./pve/deploy.nix { inherit pkgs lib host; }) (aliasMachinesOfKind [
            "pve"
          ])
        )
        // lib.optionalAttrs (!isLinux) (
          # Mac 一次性构建+激活别名：nix run .#mba-m5 等（activate 必须 root，内置 sudo）
          lib.mapAttrs (
            m: _: pkgs.writeShellScriptBin m "exec sudo ${self.darwinConfigurations.${m}.system}/activate"
          ) (aliasMachinesOfKind [ "darwin" ])
        )
      );

      # --- 多台机器部署别名：nix run .#ide-si / .#mba-m5 等（packages 块内由 mkHomeAlias / genAttrs 统一生成）---

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
          # 全目标 eval：11 standalone HM + 3 darwin + 2 nixos = 16（求值失败则 check 实例化失败）
          # unsafeDiscardStringContext：只 eval 不构建；否则 check 会把 16 个目标的 drv 当依赖，跨架构直接 platform mismatch
          targetDrvs =
            lib.mapAttrs (
              n: c: builtins.unsafeDiscardStringContext c.activationPackage.drvPath
            ) self.homeConfigurations
            // lib.mapAttrs (
              n: c: builtins.unsafeDiscardStringContext c.config.system.build.toplevel.drvPath
            ) self.darwinConfigurations
            // lib.mapAttrs (
              n: c: builtins.unsafeDiscardStringContext c.config.system.build.toplevel.drvPath
            ) self.nixosConfigurations;
          # 别名实际存在性：registry 带 alias 的机器至少出现在一个 system 的 packages 中
          aliasNames = builtins.attrNames (lib.filterAttrs (n: m: m.alias) machines);
          aliasPresent = builtins.filter (
            n: lib.any (s: builtins.hasAttr n self.packages.${s}) allSystems
          ) aliasNames;
        in
        {
          formatting = (treefmt-nix.lib.evalModule pkgs ./formatter.nix).config.build.check self;
          rustdesk-injector = pkgs.runCommand "rustdesk-injector-test" { } ''
            ${pkgs.python3}/bin/python3 ${./tests/rustdesk-injector.py} ${./tools/rustdesk-inject.py}
            touch "$out"
          '';
          # 镜像/缓存配置一致性（tools/config.nix 源头 ↔ flake.nix nixConfig ↔ Dockerfile nix.conf ↔ entrypoint.sh nix.conf ↔ pve/deploy.sh nix.conf）：
          # 四处手写静态层解析期读不到 tools（PVE 层按子集比对），只能靠检查防漂移（见 tests/mirror-consistency.py、AGENTS.md）
          mirror-consistency = pkgs.runCommand "mirror-consistency-check" { } ''
            ${pkgs.python3}/bin/python3 ${./tests/mirror-consistency.py} ${./tools/config.nix} ${./flake.nix} ${./docker/ide/ubuntu/Dockerfile} ${./docker/ide/ubuntu/entrypoint.sh} ${./pve/deploy.sh} ${./pve/apply.sh}
            touch "$out"
          '';
          # 输出集合断言：三大配置族键集与机器别名集合 == 迁移前基线（防注册漏改，见 tests/machine-sets.py）
          machine-sets = pkgs.runCommand "machine-sets-check" { } ''
            ${pkgs.python3}/bin/python3 ${./tests/machine-sets.py} \
              '${builtins.toJSON (builtins.attrNames self.homeConfigurations)}' \
              '${builtins.toJSON (builtins.attrNames self.darwinConfigurations)}' \
              '${builtins.toJSON (builtins.attrNames self.nixosConfigurations)}' \
              '${builtins.toJSON aliasPresent}'
            touch "$out"
          '';
          # 全目标 eval 门禁：16 台机器全部可求值（见 tests/eval-all-targets.py）
          eval-all-targets = pkgs.runCommand "eval-all-targets-check" { } ''
            ${pkgs.python3}/bin/python3 ${./tests/eval-all-targets.py} '${builtins.toJSON targetDrvs}'
            touch "$out"
          '';
          # scan 静默跳过门禁：tools.scan 只导入直接子 .nix 与含 default.nix 的子目录，
          # 无 default.nix 子目录内的 .nix 若未被显式 import 即被静默忽略（见 tests/check-scan-imports.py、AGENTS.md）
          scan-imports = pkgs.runCommand "scan-imports-check" { } ''
            ${pkgs.python3}/bin/python3 ${./tests/check-scan-imports.py} ${./.}
            touch "$out"
          '';
        }
      );
    };
}
