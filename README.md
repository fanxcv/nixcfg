# fan 的 Nix 配置仓库

多机 home-manager 配置（结构参考 [tsln1998/nixcfg](https://github.com/tsln1998/nixcfg)），当前管理 Docker 开发容器（ide），后续扩展 NixOS 真机与 macOS。

**宗旨：能 nix 就 nix**——软件包、配置、环境变量尽量全部交给 nix 声明式管理；实在不行的（systemd、sshd、登录 shell 这类系统级依赖）才留在 Dockerfile/系统层。改配置 = 容器内重建激活，不用重新 build 镜像。

## 仓库结构

```
nixcfg/
├── flake.nix                  # 多机器入口：注册 + 命令别名（nix run .#<机器名>）
├── docker/ide/                # ide 容器定义（docker-compose.yml + ubuntu/Dockerfile + entrypoint.sh）
├── hosts/                     # 系统层（NixOS / nix-darwin 接入模板，见 hosts/README.md）
└── home/fan/                  # home-manager 配置
    ├── default.nix            # 入口：用户身份按平台（nixos/darwin=fan，alpine=root）
    ├── _common_/              # 跨平台共享（所有机器生效）
    │   ├── base.nix           #   git 配置 + CLI 工具（rg/fd/jq/rtk，nix 管理）
    │   ├── ai.nix             #   claude-code / codex / pi + beads/ccline + claude 配置（settings/cc_claude）
    │   ├── codex.nix          #   codex 配置通用段（机器特定段本机维护，switch 自动合并）
    │   ├── container.nix      #   容器通用（isContainer=true：root 用户 + PATH）
    │   ├── mise.nix           #   mise 本体（组件清单暂空，分机器确定）
    │   ├── pi.nix             #   pi agent 配置拉取（git.fan-x.fun → ~/.pi/agent/）
    │   ├── secrets.nix        #   AI 密钥注入（$HOME/.secrets/ai.env）
    │   ├── shells.nix         #   oh-my-zsh + 插件（gh-proxy 镜像开关）
    │   ├── ssh.nix            #   公钥拉取 + sshd 加固（root/sudo 执行）
    │   └── tmux.nix           #   tmux + gpakosz 配置
    ├── _linux_/               # Linux 系公共（git/vim/curl + docker，NixOS/Alpine 共用）
    ├── _nixos_/               # NixOS 平台（真机桌面：Plasma/gui/i18n）
    ├── _ubuntu_/              # Ubuntu 平台（服务器/真机基础：make/net-tools/inetutils）
    ├── _container_/           # 容器平台（ide-si/ide-lenovo：skemate 公共，继承 _ubuntu_）
    ├── _alpine_/              # Alpine 平台（busybox/cacert + ssh 服务端配置）
    ├── _darwin_/              # macOS 平台（三台 Mac 生效）
    ├── ide-si/                # 机器微调：ide-si 容器（原 si-11-ide，代理+hosts 接管）
    ├── ide-lenovo/            # 机器微调：ide-lenovo 容器（mise 组件差异）
    └── mba-m5/ mbp-m1/ mini-m4/ nix-pve/   # 真机微调（可留空，flake 自动跳过不存在的目录）
```

**平台矩阵**：`_common_`（全平台）+ `_linux_`（Linux 系公共，NixOS/Ubuntu/Alpine 共用）+ `_${platform}_`（nixos/ubuntu/container/alpine/darwin，container 继承 ubuntu）+ `<host>`（机器微调，可选）。用户身份：nixos/darwin = fan，alpine = root；容器（isContainer=true）强制 root。

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
# mise 组件由 nix 按机器目录声明（home/fan/ide-si/mise.nix / ide-lenovo/mise.nix），激活自动写入 ~/.config/mise/config.toml
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
# packages 块内：ide-si = ...（mise 组件按机器目录声明，见 home/fan/ide-si/mise.nix）
```

→ ide-si 容器内 `nix run .#ide-si`，lenovo 用 `.#ide-lenovo`。机器专属微调放 home/fan/<host>/（ide-si 含 sysenv.nix 代理+hosts；ide-lenovo 仅 mise 差异）。

## 构建 NixOS 真机（待补）

接入方式：flake.nix 一行注册（platform = "nixos"，默认用户 fan）+ `hosts/` 系统层配置（见 `hosts/README.md`）。机器微调放 `home/fan/<hostName>/default.nix`。

```nix
"fan@laptop" = mkHomeConfig { hostName = "laptop"; system = "x86_64-linux"; };
laptop = self.homeConfigurations."fan@laptop".activationPackage;   # packages 块
```

> TODO：系统层（nixosConfigurations）、本机密钥文件初始化、首装流程待补。

## 构建 macOS（待补）

接入方式：注册 platform = "darwin"，用户 fan（`/Users/fan`），nix-darwin 系统层见 `hosts/README.md`。mac 自带 git/vim/curl，`_common_` 的 ai/mise/shells/tmux/secrets 全部生效。

```nix
"fan@macbook" = mkHomeConfig { hostName = "macbook"; system = "aarch64-darwin"; platform = "darwin"; };
macbook = self.homeConfigurations."fan@macbook".activationPackage;  # packages 块
```

> TODO：darwinConfigurations 系统层、密钥文件初始化（`~/.secrets/ai.env`）、首装流程待补。

## 密钥与环境变量（三平台通用）

| 平台 | 密钥文件 | 来源 |
|---|---|---|
| 容器（root） | `/root/.secrets/ai.env` | compose 挂载宿主机 |
| NixOS 真机（fan） | `/home/fan/.secrets/ai.env` | 本机文件（chmod 600） |
| mac（fan） | `/Users/fan/.secrets/ai.env` | 本机文件（chmod 600） |

`_common_/secrets.nix` 统一 `source $HOME/.secrets/ai.env`（缺失静默跳过），密钥不进 nix 配置、不提交 git。`ai.env` 只存三个源 key（AI_FAN_CLAUDE / AI_FAN_CODEX / AI_FAN_CHAT），工具变量（ANTHROPIC_AUTH_TOKEN、PIPI_*）由 secrets.nix 映射派生；`PI_CONFIG_GIT_TOKEN` 供 pi 配置仓库拉取（`_common_/pi.nix`）。非敏感全局变量用 `home.sessionVariables`（全平台生效）。

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

## 与 alpine-init.sh 的迁移对照

| alpine-init.sh | 本仓库 |
|---|---|
| install_packages（apk/apt 基础包） | `_linux_/base.nix`（git/vim/curl）+ `_ubuntu_/base.nix`（make/net-tools，容器经 `_container_` 继承）+ `_alpine_/base.nix`（busybox/cacert） |
| git config --global | `_common_/base.nix` programs.git |
| install_oh_my_zsh（gh-proxy） | `_common_/shells.nix`（clone + 插件 + 主题） |
| install_mise | `_common_/mise.nix`（mise 本体；组件清单分机器确定） |
| install_docker + compose + network fan | `_linux_/docker.nix`（仅 Linux 系，容器跳过） |
| ssh_config（公钥 + 禁密码） | `_common_/ssh.nix`（activation，防锁死回滚） |
| post_config_alpine（PubkeyAcceptedKeyTypes） | `_alpine_/ssh.nix` |
| BBR / TUN / root shell / apk·apt 源 | 系统级，装机时处理（Dockerfile / 系统层） |
