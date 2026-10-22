# hosts/ —— 系统层配置（对应 nixcfg 的 hosts/ 目录）

home/fan/ 管**用户环境**（跨机器共用），hosts/ 管**系统本身**：
用户账号、服务（docker/ssh）、内核、桌面等。只有 NixOS / nix-darwin
机器才需要这层；Alpine/Ubuntu 容器和服务器没有这层，系统部分用脚本。

## 目录约定（对齐 nixcfg）

```
hosts/
├── _common_/    # 跨平台系统配置（模块：用户、时区、i18n）
├── _nixos_/     # NixOS 专属（服务、内核、桌面）
├── _darwin_/    # macOS 专属（homebrew、系统偏好）
└── <host>/      # 单机：imports 组装清单（如 hosts/mini-m4/default.nix）
```

## 接入一台 NixOS 机器（三步）

```nix
# 1. hosts/_nixos_/ 下写平台公共模块（用户、ssh、docker 服务……）
#    { config, pkgs, ... }: {
#      users.users.fan = { isNormalUser = true; extraGroups = [ "wheel" "docker" ]; };
#      services.openssh.enable = true;
#      services.docker.enable = true;
#    }

# 2. hosts/<hostName>/default.nix 写机器组装清单：
#    { lib, ... }: {
#      imports = [ ../_common_ ../_nixos_ ];   # 或按需
#      networking.hostName = "laptop";
#      system.stateVersion = "25.05";
#    }

# 3. flake.nix 注册（inputs 需加 nixpkgs/nixos-hardware/home-manager 模块）：
#    nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
#      system = "x86_64-linux";
#      modules = [
#        ./hosts/laptop
#        inputs.home-manager.nixosModules.home-manager
#        { home-manager.useGlobalPkgs = true;
#          home-manager.extraSpecialArgs = { inherit inputs outputs; };
#          home-manager.users.fan = import ../home/fan { }; }   # 复用同一份 home 配置
#      ];
#      specialArgs = { inherit inputs outputs; };
#    };
```

接入后：`nixos-rebuild switch --flake .#laptop` 一条命令管理整机，
home/fan/_common_/ 的配置自动生效。macOS 同理，用 nix-darwin 的 `darwinSystem`。

## macOS（已接入三台）

`darwinConfigurations` 已注册 mba-m5 / mbp-m1 / mini-m4（flake.nix），结构：

```
hosts/_common_/        # 跨平台系统层（agenix 身份/时区）
hosts/_darwin_/        # macOS 平台层：default.nix=三台共用组装清单；
                       #   base（homebrew 声明式 + casks）gui（quartz 桌面声明：
                       #   Dock/Finder/触控板/菜单栏/截图…）i18n（字体）
                       #   kernel（pmset 电源/关更新/关开机音）
hosts/<机>/            # 机器差异层：只放本机文件（tailscale.nix/udev 规则等机器独有项…）
users/fan/             # 用户定义：primaryUser + home-manager 内嵌
home/fan/<host>/       # 用户层组装（_common_ 跨平台 + _darwin_ 平台层）
```

每台机器：`darwin-rebuild switch --flake .#<host>`（或 `nix run .#<host>`，别名内置 sudo）。
homebrew casks 在
`hosts/_darwin_/base/apps.nix`，增删即装卸；未声明的 casks 会自动卸载（cleanup=zap）。

## 部署方式

各机均手动部署：`nixos-rebuild switch --flake .#<机>`（NixOS）/ `nix run .#<机>`（macOS、容器、PVE 宿主）。
仓库不提供自动部署（comin 已随 nix-pve 于 2026-10 退役而移除，flake input 与 overlay 一并删除）。
