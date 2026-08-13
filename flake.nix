{
  description = "fan 的 Nix 配置仓库（多机共用，结构参考 tsln1998/nixcfg）";

  # 二进制缓存默认走国内镜像（与 install.sh 生成的 /etc/nix/nix.conf 一致）
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
    # git+https 走 gh-proxy（国内 GitHub 直连超时）：flakes fetcher 无法配置镜像，URL 前置代理最稳
    # 稳定版 nixos-26.05：闭包二进制在镜像/官方永久缓存 → 构建全命中 USTC/TUNA，不随每日更新失效；
    # rev 锁到国内镜像已同步的 channel 点更新版本（升级：跑 scripts/update-nixpkgs.sh）
    nixpkgs.url = "git+https://gh-proxy.com/https://github.com/NixOS/nixpkgs.git?ref=nixos-26.05&rev=70cc4559b10a6062b05ff1af17e0add065ccaed9&shallow=1";
    home-manager = {
      # 与 nixpkgs 26.05 配套的 release 分支（master 要求更新的 nixpkgs）
      url = "git+https://gh-proxy.com/https://github.com/nix-community/home-manager.git?ref=release-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secrets 加密（agenix）：secrets/*.age 激活时自动解密，见 _common_/secrets.nix 与 secrets/README.md
    agenix = {
      url = "git+https://gh-proxy.com/https://github.com/ryantm/agenix.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 代码格式化（nix fmt）：nixfmt + statix，配置见 formatter.nix
    treefmt-nix = {
      url = "git+https://gh-proxy.com/https://github.com/numtide/treefmt-nix.git?ref=main&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # git 驱动的自动部署（服务器轮询仓库自动 nixos-rebuild），等真机接入后启用
    comin = {
      url = "git+https://gh-proxy.com/https://github.com/nlewo/comin.git?ref=refs/tags/v0.14.0&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      # comin 内部自带的 treefmt-nix 整体跟随（否则它解析 github 旧版 + 旧 nixpkgs，lock 残留双节点）
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    # --- NixOS 真机（nix-pve，PVE 上的虚拟机）：声明式磁盘 / 不可变系统 / Plasma 桌面 ---
    # 注意：新增 input 用直连 GitHub（走代理拉取；gh-proxy 限流时锁不动），已有 input 保持 gh-proxy
    disko = {
      url = "git+https://github.com/nix-community/disko.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "git+https://github.com/nix-community/impermanence.git?ref=master&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Plasma 面板/字体/KWin 声明式定制（home 层，见 home/fan/_nixos_/gui/plasma.nix）
    plasma-manager = {
      url = "git+https://github.com/nix-community/plasma-manager.git?ref=trunk&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # --- macOS（nix-darwin）：三台 Mac 的系统层，见 hosts/_darwin_/ 与 hosts/<host>/ ---
    # nix-darwin 用配套分支：nix-darwin-26.05 ↔ nixpkgs-26.05-darwin（checkRelease 强制匹配）
    nixpkgs-darwin = {
      # darwin 专属 channel（闭包含完整 darwin 构建，镜像同步），rev 锁镜像同步点
      url = "git+https://gh-proxy.com/https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-26.05-darwin&rev=2e49fce950fece113519c5d75da869601d01550f&shallow=1";
    };
    nix-darwin = {
      url = "git+https://gh-proxy.com/https://github.com/nix-darwin/nix-darwin.git?ref=nix-darwin-26.05&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };

    # homebrew 声明式管理（casks 清单见 hosts/_darwin_/base/apps.nix）
    nix-homebrew = {
      url = "git+https://gh-proxy.com/https://github.com/zhaofengli/nix-homebrew.git?ref=main&shallow=1";
      inputs.brew-src.follows = "homebrew";
    };
    homebrew = {
      url = "git+https://gh-proxy.com/https://github.com/Homebrew/brew.git?ref=main&shallow=1";
      flake = false;
    };
    homebrew-core = {
      url = "git+https://gh-proxy.com/https://github.com/homebrew/homebrew-core.git?ref=main&shallow=1";
      flake = false;
    };
    homebrew-cask = {
      url = "git+https://gh-proxy.com/https://github.com/homebrew/homebrew-cask.git?ref=main&shallow=1";
      flake = false;
    };
    # tart 等公式的 tap（mini-m4 的 hosts/mini-m4/homebrew.nix 声明）
    cirruslabs-cli = {
      url = "git+https://gh-proxy.com/https://github.com/cirruslabs/homebrew-cli.git?ref=master&shallow=1";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, home-manager, agenix, treefmt-nix, comin, nix-darwin, ... }@inputs:
    let
      # outputs == self（flake 自身），模块里统一用这个引用
      outputs = self;
      lib = nixpkgs.lib;
      # 目录扫描/相对路径工具（模块自动导入，见 tools/scan.nix、tools/relative.nix）
      tools = import ./tools { inherit lib self; };
      # claude-code 分发镜像（npm 平台包走 npmmirror），定义见 overlays/claude-code.nix
      # skemate（自研终端复用服务）官方二进制分发，定义见 overlays/skemate.nix
      # overlay 无法在 home 模块层注册（pkgs 先于模块构造），只能在此注入
      claudeOverlay = import ./overlays/claude-code.nix { inherit lib; };
      skemateOverlay = import ./overlays/skemate.nix { inherit lib; };
      # 每个 system 生成一套可运行包（nix run 一步 build+activate）
      forAllSystems = lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      # 生成指定机器上的 home 配置（用户由 home/fan/default.nix 决定：Linux=root / darwin=fan）
      #   hostName:        机器名（容器 hostname 由部署层 docker-compose 决定，与此无关）
      #                     home/fan/<hostName>/ 目录可选：存在则注入机器微调，不存在自动跳过
      #   system:          架构（aarch64-linux / x86_64-linux / aarch64-darwin）
      #   platform:        平台（nixos=Linux系容器/NixOS / alpine=Alpine服务器 / darwin=macOS，
      #                     注入 home/fan/_nixos_ 或 _alpine_ 或 _darwin_）
      #   useChinaMirror:  是否走国内镜像（false 时 mise 等直连官方源）
      #   isContainer:     是否容器环境（容器里 docker daemon 起不来，不安装 docker 全家桶；
      #                     容器用户覆盖为 root，见 _common_/container.nix）
      mkHomeConfig =
        { hostName, system ? "aarch64-linux", platform ? "nixos", useChinaMirror ? true, isContainer ? false, ideMachine ? null }:
        home-manager.lib.homeManagerConfiguration {
          # claude-code 在 nixpkgs 标记 unfree，用 predicate 只放行它（import 重新求值带 config 的 pkgs）
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
            overlays = [ claudeOverlay skemateOverlay ];
          };
          modules = [
            ./home/fan
            ./home/fan/_${platform}_
          ] ++ lib.optionals (builtins.pathExists ./home/fan/${hostName}) [
            ./home/fan/${hostName}
          ];
          extraSpecialArgs = {
            inherit self inputs outputs tools useChinaMirror hostName isContainer platform ideMachine;
          };
        };
      # 生成指定 macOS 机器的 nix-darwin 配置（home-manager 内嵌，darwin-rebuild 一次管全部）
      #   系统层：hosts/<hostName>/default.nix 组装（见 hosts/README.md）
      #   用户层：users/fan 的 home-manager.users 指向 home/fan/<hostName>/
      mkDarwinConfig = { hostName, system ? "aarch64-darwin" }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        # mac 用 nixpkgs-26.05-darwin channel（darwin 闭包完整，镜像命中）；与 nix-darwin-26.05 分支配套
        pkgs = import inputs."nixpkgs-darwin" {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];
          overlays = [ claudeOverlay skemateOverlay ];
        };
        modules = [
          ./hosts/${hostName}
          {
            networking.hostName = hostName;
          }
        ];
        specialArgs = {
          inherit self inputs outputs tools;
          # darwin 固定值（与 mkHomeConfig 的注入对齐，home 层模块统一取用）
          useChinaMirror = true;
          isContainer = false;
          platform = "darwin";
        };
      };
    in
    {
      homeConfigurations = {
        # Docker 开发容器（Ubuntu，si-11-ide / lenovo-ide）：容器里 docker daemon 跑不起来，isContainer=true 跳过 docker 安装
        # 所有容器均走代理（compose 层 http_proxy 等环境变量），网络环境一致，不再区分国内/国外变体
        # 机器专属：mise 组件按容器声明（home/fan/ide/mise.nix），容器内 nix run .#ide-si11 / .#ide-lenovo
        "fan@ide-si11" = mkHomeConfig { hostName = "ide"; ideMachine = "si11"; isContainer = true; };
        "fan@ide-lenovo" = mkHomeConfig { hostName = "ide"; ideMachine = "lenovo"; isContainer = true; };

        # --- 多台 ide 开发容器：一行注册即可（机器目录可选），hostname 在部署层 docker-compose 里设 ---
        # "fan@ide-eu" = mkHomeConfig { hostName = "ide-eu"; isContainer = true; };
        # "fan@ide-us" = mkHomeConfig { hostName = "ide-us"; isContainer = true; };

        # --- 以后加真机：一行注册 + 对应目录，例如 ---
        # "fan@macbook" = mkHomeConfig { hostName = "macbook"; system = "aarch64-darwin"; platform = "darwin"; };
        # "fan@laptop"  = mkHomeConfig { hostName = "laptop"; system = "x86_64-linux"; };
      };

      # --- macOS：三台 nix-darwin（home-manager 内嵌，darwin-rebuild switch --flake .#<机器>）---
      # 系统层组装见 hosts/<host>/default.nix，用户层自动挂载 home/fan/<host>/
      darwinConfigurations = {
        mba-m5 = mkDarwinConfig { hostName = "mba-m5"; };
        mbp-m1 = mkDarwinConfig { hostName = "mbp-m1"; };
        mini-m4 = mkDarwinConfig { hostName = "mini-m4"; };
      };

      # --- NixOS 真机：nix-pve（Proxmox VE 上的虚拟机，128G 盘 + KDE Plasma 桌面）---
      # 系统层：hosts/nix-pve/default.nix（disko 分区 / impermanence 持久化 / Plasma 桌面）
      # 用户层：users/fan 的 home-manager.users 指向 home/fan/nix-pve（复用同一份 home 配置）
      # 部署：nixos-rebuild switch --flake .#nix-pve（手动；comin 自动部署未启用）
      nixosConfigurations.nix-pve = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # 与 mkHomeConfig 同款 pkgs：claude-code 镜像 overlay + unfree 放行（claude-code / microsoft-edge / libsciter[clash-verge-rev]）
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" "microsoft-edge" "libsciter" ];
          overlays = [ claudeOverlay skemateOverlay ];
        };
        modules = [ ./hosts/nix-pve ];
        specialArgs = {
          inherit self inputs outputs tools;
          useChinaMirror = true;
          isContainer = false;
          platform = "nixos";
        };
      };

      # --- 简短命令别名：nix build .#<机器名> && ./result/activate（两步）---
      # homeConfigurations 标准名保留（兼容 home-manager switch --flake 等工具）

      # --- 一步到位：nix run .#<机器名>（构建 + activate 一条命令）---
      # ide 容器可能跑在不同架构服务器（lenovo/si-11 等），激活配置必须按当前 system 构建：
      # 不能引用固定架构的 homeConfigurations（会 platform mismatch，如 x86_64 机器拿到 aarch64 配置）
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          # 机器专属别名：mise 组件按容器声明（home/fan/ide/mise.nix），si-11/lenovo 各一份
          # HOME_MANAGER_BACKUP_EXT=backup：已存在的手配文件（如 .codex/config.toml）自动备份为 .backup 再覆盖
          ide-si11 = pkgs.writeShellScriptBin "ide-activate"
            "export USER=root; export HOME_MANAGER_BACKUP_EXT=backup; exec ${(mkHomeConfig { hostName = "ide"; system = system; ideMachine = "si11"; isContainer = true; }).activationPackage}/activate";
          ide-lenovo = pkgs.writeShellScriptBin "ide-activate"
            "export USER=root; export HOME_MANAGER_BACKUP_EXT=backup; exec ${(mkHomeConfig { hostName = "ide"; system = system; ideMachine = "lenovo"; isContainer = true; }).activationPackage}/activate";
          # Mac 一次性构建+激活别名：nix run .#darwin-mba-m5 等
          "darwin-mba-m5" = pkgs.writeShellScriptBin "darwin-mba-m5"
            "exec ${self.darwinConfigurations.mba-m5.system}/activate";
          "darwin-mbp-m1" = pkgs.writeShellScriptBin "darwin-mbp-m1"
            "exec ${self.darwinConfigurations.mbp-m1.system}/activate";
          "darwin-mini-m4" = pkgs.writeShellScriptBin "darwin-mini-m4"
            "exec ${self.darwinConfigurations.mini-m4.system}/activate";
        });

      # --- 多台 ide 部署的别名同规则：nix build .#ide-si11 / .#ide-lenovo（packages 块内各一行）---

      # 代码格式化：nix fmt 一键格式化（treefmt：nixfmt + statix，配置见 formatter.nix）
      formatter = forAllSystems (system:
        (treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./formatter.nix).config.build.wrapper);

      # 格式检查：nix flake check（本地/CI 均可用）
      checks = forAllSystems (system: {
        formatting =
          (treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./formatter.nix).config.build.check self;
      });
    };
}
