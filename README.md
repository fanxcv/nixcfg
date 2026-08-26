# fan 的 Nix 配置仓库

多机 Nix 配置，当前管理三台 Mac、NixOS 真机 nix-pve、两个 Docker 开发容器与六台 PVE 宿主机。

**宗旨：能 nix 就 nix**——软件包、配置、环境变量尽量全部交给 nix 声明式管理；实在不行的（systemd、sshd、登录 shell 这类系统级依赖）才留在 Dockerfile/系统层。改配置 = 容器内重建激活，不用重新 build 镜像。

## 仓库结构

```
nixcfg/
├── flake.nix                  # 多机器入口：注册 + 命令别名（nix run .#<机器名>）
├── docker/ide/                # ide 容器定义（docker-compose.yml + ubuntu/Dockerfile + entrypoint.sh）
├── hosts/                     # 系统层（NixOS / nix-darwin，见 hosts/README.md）
├── modules/home/              # 可复用 Home Manager 软件模块（ai/codex/mise/pi/ssh/tmux/vscode）
└── home/fan/                  # home-manager 配置
    ├── default.nix            # 入口：用户身份按平台（nixos/darwin=fan，容器由 isContainer 强制 root）
    ├── _common_/              # 跨平台共享（所有机器生效）
    │   ├── base.nix           #   git 配置 + CLI 工具（rg/fd/jq/rtk，nix 管理）
    │   ├── container.nix      #   容器身份/PATH 适配
    │   ├── mirrors.nix        #   npm/pip/uv/go/flutter 镜像
    │   ├── path.nix           #   激活环境 PATH 修复
    │   ├── secrets.nix        #   age 解密 + AI 环境变量映射
    │   └── shells.nix         #   oh-my-zsh + 插件（gh-proxy 镜像开关）
    ├── _linux_/               # Linux 系公共（git/vim/curl + docker，NixOS/Ubuntu 共用）
    ├── _nixos_/               # NixOS 平台（真机桌面：Plasma/gui/i18n）
    ├── _ubuntu_/              # Ubuntu 平台（服务器/真机基础：make/net-tools/inetutils）
    ├── _container_/           # 容器平台（ide-si/ide-lenovo：skemate 公共，继承 _ubuntu_）
    ├── _darwin_/              # macOS 平台（三台 Mac 生效）
    ├── ide-si/                # 机器微调：ide-si 容器（原 si-11-ide，代理+hosts 接管）
    ├── ide-lenovo/            # 机器微调：ide-lenovo 容器（mise 组件差异）
    └── mba-m5/ mbp-m1/ mini-m4/ nix-pve/   # 真机微调（可留空，flake 自动跳过不存在的目录）
```

**平台矩阵**：`_common_`（全平台）+ `_linux_`（Linux 系公共，NixOS/Ubuntu 共用）+ `_${platform}_`（nixos/ubuntu/container/darwin，container 继承 ubuntu）+ `<host>`（机器微调，可选）。用户身份：nixos/darwin = fan；容器（isContainer=true）强制 root。

## 构建 ide 容器（Docker 开发容器）

### 1. 宿主机准备（首次）

```bash
# 宿主机：clone 仓库（compose 在仓库内 docker/ide/，挂载整个仓库进容器）
git clone <你的仓库地址> /root/nixcfg && cd /root/nixcfg/docker/ide

# 可选：预创建 IDE 挂载目录（不建 Docker 会自动创建空目录）
mkdir -p vsc JetBrains/cache JetBrains/config JetBrains/share

# 容器定义：Ubuntu 24.04 + systemd(PID1) + sshd + nix（清华镜像安装，单用户模式）
# 系统层只保留"实在不行"的部分，软件包全部由 nix 管理

# AI 密钥文件（宿主机，chmod 600；容器内由 nix 的 secrets.nix 自动注入）
mkdir -p /root/.secrets && chmod 700 /root/.secrets
cat > /root/.secrets/ai.env <<'EOF'
export AI_FAN_CLAUDE=sk-...                  # claude key（claude code / pi）
export AI_FAN_CODEX=sk-...                   # codex key（pi）
export AI_FAN_CHAT=sk-...                    # chat key（codex CLI / pi）
export PI_CONFIG_GIT_TOKEN=6aef...           # pi 配置仓库只读密钥（git.fan-x.fun，可选）
EOF
chmod 600 /root/.secrets/ai.env

# git 凭据（可选，~/.git-credentials 由 nix 从该文件生成）
# 每行一个：https://user:token@host
cat > /root/.secrets/git-credentials <<'EOF'
https://fan:xxxxx@git.fan-x.fun
EOF
chmod 600 /root/.secrets/git-credentials
```

### 2. 构建 + 启动

```bash
docker compose build
docker compose up -d        # systemd 启动，sshd 自启（端口 2222→22）
```

### 3. 容器内首次激活

```bash
docker exec -it ide bash     # 首次 SSH 还没公钥，用 docker exec

cd /root/nixcfg            # 配置仓库已由宿主机拉取并挂载，无需 clone
nix run .#ide-si          # ide-si 容器（原 si-11-ide）；lenovo 容器用 .#ide-lenovo（构建 + 激活：拉公钥、加固 sshd、oh-my-zsh/tmux 配置就位）
# mise 组件由 home/fan/_container_/mise.nix 按 hostName 声明，激活自动写入 ~/.config/mise/config.toml
```

### 4. 验证

```bash
zsh -ic 'echo $ZSH_THEME'    # fishy-custom
git config user.name         # fan
which claude codex pi        # 都应指向 /nix/store/... 或 ~/.nix-profile/bin
rg --version                 # ripgrep（nix 安装，全平台）
```

之后 SSH 用公钥进入（`ssh -p 2222 root@<宿主>`；authorized_keys 由激活时自动拉取）。

### 5. 日常更新（改配置 / 升级工具）

```bash
# 宿主机（推荐）或容器内（挂载目录，同一份文件）更新配置仓库
git -C ./nixcfg pull         # 宿主机
# 或容器内：cd /root/nixcfg && git pull

# 容器内应用配置改动（ide-si / lenovo 分别用 .#ide-si / .#ide-lenovo）
nix run .#ide-si

# 升级 nixpkgs 里的工具版本（claude/codex/pi 等新版本）
# 稳定版 nixos-26.05 不锁 rev，nix flake update 直接跟随分支点更新（构建命中镜像缓存）
nix flake update && nix run .#ide-si
```

**不需要重新 build 镜像**——只有动 systemd/sshd 本体/zsh 登录 shell 时才需要改 `docker/ide/ubuntu/Dockerfile` 并重建。

### 6. 多台部署

每台服务器只需 flake.nix 两行 + 部署层各管各的（hostname 在 compose 里设，密钥在各自宿主机）：

```nix
"fan@ide-si" = mkHomeConfig { hostName = "ide-si"; platform = "container"; isContainer = true; };
"fan@ide-lenovo" = mkHomeConfig { hostName = "ide-lenovo"; platform = "container"; isContainer = true; };
# packages 块内：ide-si = ...（mise 组件见 home/fan/_container_/mise.nix 的 hostName 分支）
```

→ ide-si 容器内 `nix run .#ide-si`，lenovo 用 `.#ide-lenovo`。机器专属微调放 home/fan/<host>/（ide-si 含 sysenv.nix 代理+hosts；ide-lenovo 仅 mise 差异）。

## 构建 NixOS 真机（已接入 nix-pve）

`nix-pve` 已由 `nixosConfigurations.nix-pve` 管理；系统层见 `hosts/nix-pve/`，用户层见 `home/fan/nix-pve/`。

```bash
sudo nixos-rebuild switch --flake .#nix-pve
```

comin 已启用，会轮询 `main` 自动部署；手动命令用于首次接入和故障恢复。

## 构建 macOS（已接入三台）

系统层由 nix-darwin 管理，用户层由 Home Manager 管理；当前目标为 `mba-m5`、`mbp-m1`、`mini-m4`。

```bash
nix run .#mba-m5
nix run .#mbp-m1
nix run .#mini-m4
```

mini-m4 已启用 comin 自动部署；三台机器的系统层结构见 `hosts/README.md`。

## 密钥与环境变量（三平台通用）

| 平台 | 密钥文件 | 来源 |
|---|---|---|
| 容器（root） | `/root/.secrets/ai.env` | `secrets/ai.env.age`（activation 解密；私钥由宿主机挂载） |
| NixOS 真机（fan） | `/home/fan/.secrets/ai.env` | `secrets/ai.env.age`（activation 解密） |
| mac（fan） | `/Users/fan/.secrets/ai.env` | `secrets/ai.env.age`（activation 解密） |

`_common_/secrets.nix` 在 activation 阶段用 `$HOME/.secrets/age-keys.txt` 解密 `ai.env` 与 git 凭据；私钥缺失或解密失败会中止部署。zsh 启动时仅在 `ai.env` 已存在时 source。`ai.env` 只存三个源 key（AI_FAN_CLAUDE / AI_FAN_CODEX / AI_FAN_CHAT），工具变量（ANTHROPIC_AUTH_TOKEN、PIPI_*）由 secrets.nix 映射派生；`PI_CONFIG_GIT_TOKEN` 供 pi 配置仓库拉取（`modules/home/pi.nix`）。非敏感全局变量用 `home.sessionVariables`。

## 镜像控制

| 层级 | 国内环境（默认） |
|---|---|
| Dockerfile 装 nix | 清华镜像（install 脚本 + tarball + binary cache） |
| home 配置 | `fan@ide-si` / `fan@ide-lenovo`（mise 走 npmmirror、git 走 gh-proxy） |

所有容器网络环境各管各的：ide-si 走代理（nix 接管：sysenv.nix 环境变量+hosts），lenovo 国内直连。

优先级：命令行 `--option` > `NIX_CONFIG` > `/etc/nix/nix.conf` > flake `nixConfig`。

## 常用命令

```bash
nix run .#ide-si          # ide-si 构建 + 激活（一步）；lenovo 用 .#ide-lenovo
nix build .#ide-si && ./result/activate   # 两步法
nix flake update            # 升级全部依赖（nixpkgs 稳定版点更新，构建走国内缓存）
nix flake check              # 语法检查（有 nix 的机器上）
```

## 与旧初始化脚本的迁移对照

| 旧脚本步骤 | 本仓库 |
|---|---|
| install_packages（apt 基础包） | `_linux_/base.nix`（git/vim/curl）+ `_ubuntu_/base.nix`（make/net-tools，容器经 `_container_` 继承） |
| git config --global | `_common_/base.nix` programs.git |
| install_oh_my_zsh（gh-proxy） | `_common_/shells.nix`（clone + 插件 + 主题） |
| install_mise | `modules/home/mise.nix`（mise 本体；组件清单由 `_container_/mise.nix` 按机器确定） |
| install_docker + compose + network fan | `_linux_/docker.nix`（仅 Linux 系，容器跳过） |
| ssh_config（公钥 + 禁密码） | `modules/home/ssh.nix`（activation，防锁死回滚） |
| BBR / TUN / root shell / apt 源 | 系统级，装机时处理（Dockerfile / 系统层） |
