# fan 的 Nix 配置仓库

多机 Nix 配置：3 台 Mac、2 台 NixOS 真机、3 个 Docker 开发容器、2 台云服务器、6 台 PVE 宿主机（共 16 台）。

**宗旨：能 nix 就 nix**——软件包、配置、环境变量尽量全交 nix 声明式管理；实在不行的（systemd、sshd、登录 shell）才留在 Dockerfile/系统层。nix 模块即配置的唯一载体，改配置就是改 nix（见 AGENTS.md）。

## 机器矩阵（16 台）

| 平台 | 机器 | 部署命令 | comin 自动 |
|---|---|---|---|
| macOS | mba-m5 / mbp-m1 / mini-m4 | `nix run .#mba-m5`（余同） | — |
| NixOS | nix-pve / nix-lenovo | `nixos-rebuild switch --flake .#nix-pve` | nix-pve |
| IDE 容器 | ide-si / ide-lenovo / ide-mac | 容器内 `nix run .#ide-si`（余同） | — |
| 云服务器 | ali-ai / hc-pro-pve-2 | `nix run .#ali-ai`（余同） | — |
| PVE 宿主 | ds2 / desktop / fan / hp / mi / razer | `nix run .#ds2`（余同） | — |

## 分层模型

```
系统层  hosts/          darwin/NixOS 系统（_darwin_/_nixos_ 公共层 + <机> 微调）
用户层  home/fan/       home-manager（平台层 + <机> 微调，module-list.nix 组装）
机器层  hosts/<机>/ + home/fan/<机>/   机器专属（目录可留空，flakes 自动跳过）
```

平台继承链：`_common_`（全平台）→ `_linux_`（Linux 系公共）→ `_${platform}_`（nixos / ubuntu / container / darwin / pve，container 继承 ubuntu）→ `<host>`（机器微调）。用户身份：nixos/darwin = fan；容器 / ubuntu / pve = root（`identity.nix` 的 `isRootHome`）。

## 快速命令

| 场景 | 命令 |
|---|---|
| IDE 容器构建+激活 | 容器内 `nix run .#ide-si` / `.#ide-lenovo` / `.#ide-mac` |
| macOS 构建+激活 | `nix run .#mba-m5` / `.#mbp-m1` / `.#mini-m4`（激活内置 sudo） |
| NixOS 切换 | `sudo nixos-rebuild switch --flake .#nix-pve` / `.#nix-lenovo` |
| PVE 宿主部署 | `nix run .#ds2` / `.#desktop` / `.#fan` / `.#hp` / `.#mi` / `.#razer` |
| 升级依赖 | `nix flake update` |

## 分平台部署

### IDE 容器（Ubuntu 24.04 + systemd + sshd + nix）

compose 是**三个具名文件**（无默认 docker-compose.yml），在 `docker/ide/` 目录下执行：

```bash
docker compose -f docker/ide/docker-compose-si.yml up -d   # lenovo 用 -lenovo.yml，mac 用 -mac.yml
docker exec -it ide bash                                   # 首次无公钥时
git pull && nix run .#ide-si                               # 容器内：拉配置 + 构建激活
```

密钥前置（宿主机，容器重建不丢）：

```bash
mkdir -p /root/.secrets && chmod 700 /root/.secrets
cat > /root/.secrets/ai.env <<'EOF'
export AI_FAN_CLAUDE=sk-...   # claude key
export AI_FAN_CODEX=sk-...    # codex key
export AI_FAN_CHAT=sk-...     # chat key
EOF
chmod 600 /root/.secrets/ai.env
# 另需 age 私钥 /root/.secrets/age-keys.txt（chmod 600，缺了 activation 直接失败）
```

日常改配置只需 `git pull && nix run .#<容器>`，**不用重建镜像**——只有动 systemd/sshd/登录 shell 才改 `docker/ide/ubuntu/Dockerfile` 并 rebuild。

### NixOS 真机

nix-pve（PVE 上的虚拟，disko 分区 + impermanence）comin 轮询 `main` 自动部署，手动命令用于首次接入/故障恢复；nix-lenovo（Lenovo ThinkBook 14 G6+ AHP 笔记本）无 comin，手动 `nixos-rebuild`。

### macOS

`nix run .#<机器>` 一步构建+激活（nix-darwin 系统层 + home-manager 用户层）；macOS 三台均无 comin（mini-m4 曾启用，2026-09 移除），手动 `nix run` 部署。系统层结构见 `hosts/README.md`。

### PVE 宿主机

`nix run .#<机器>` = bootstrap nix → 推 git 凭据 → clone 仓库 → 远程构建 HM + activate → 系统层 apply（机制见 `pve/deploy.nix`，机器目录 `pve/<机>/`）。

### 云服务器（B 路线）

`ali-ai` / `hc-pro-pve-2` 保留发行版（Ubuntu），nix 只管用户态：`nix run .#<机>` 构建 HM，并把渲染好的 compose / 配置经 systemd-run 派发到系统层。

## 密钥与环境变量

`secrets/` 用 age 加密入库（明文在 `secrets/source/`，`./secrets/encrypt.sh` 生成 .age；公钥明文入库，私钥在 `$HOME/.secrets/age-keys.txt`）。激活时 `home.activation` 用 age 私钥解密 `ai-env` 到三平台同一位置，**私钥缺失或解密失败即部署中止**：

| 平台 | 解密产物 | 内容 |
|---|---|---|
| 容器（root） | `/root/.secrets/ai.env` | AI_FAN_CLAUDE / AI_FAN_CODEX / AI_FAN_CHAT + 派生的工具变量 |
| NixOS 真机（fan） | `/home/fan/.secrets/ai.env` | 同上 |
| mac（fan） | `/Users/fan/.secrets/ai.env` | 同上 |

命名/位置规则（公共 vs 机器独有、跨机引用）见 `secrets/README.md`。

## 仓库结构

```
nixcfg/
├── flake.nix              # 入口：机器注册 + 命令别名 + formatter/checks
├── hosts/                 # 系统层：_darwin_/_nixos_ 公共 + <机>（darwin 见 hosts/README.md）
├── home/fan/              # 用户层：_common_/_<平台>_ 公共 + <机> 微调（module-list.nix 组装）
├── users/fan/             # NixOS 真机用户层（复用 home/fan 模块清单）
├── modules/               # 可复用模块库：home/（ai/codex/mise/pi/ssh/tmux/vscode/catppuccin）、darwin/、nixos/
├── overlays/              # nixpkgs overlay：skemate（flake.lock 锁定 rev，见 inputs）、unstable/vscode 市场、comin 等
├── packages/              # 本地自打包（kasmvnc、rustdesk-bin、KDE 商店主题等）
├── docker/ide/            # IDE 容器定义（compose si/lenovo/mac 三文件 + ubuntu/Dockerfile）
├── pve/                   # PVE 宿主系统层 + 部署脚本（apply.sh/deploy.sh/deploy.nix）
├── secrets/               # age 加密密钥（encrypt.sh 生成，git 可公开）
├── tools/                 # flake 工具库：config.nix（镜像/代理唯一入口）、sshUserKeys.nix（SSH 身份清单）、目录扫描、syncthing 配置
├── scripts/               # 运维脚本（switch-github-proxy.sh）
├── tests/                 # 门禁脚本（镜像一致性 / 机器集合 / 全目标 eval / scan 导入 / rustdesk 注入器）
├── docs/                  # 维护手册
└── assets/                # 静态资源（catppuccin 渐变壁纸等）
```

## 镜像与网络

镜像/代理策略集中 `tools/config.nix`（`useChinaMirror` / `githubFetchBase` 唯一入口，机器级可覆盖）；容器网络各管各的：ide-si 走代理（nix 接管环境变量+hosts），lenovo / mac 国内直连；nix 安装/二进制缓存走 CERNET 联合镜像（`mirrors.cernet.edu.cn`），git 拉取走 ghfast.top 前缀。切换 GitHub 代理见 `scripts/switch-github-proxy.sh`。

## 常用命令

```bash
nix run .#<机器>            # 一步构建+激活（容器/mac/PVE）；NixOS 用 nixos-rebuild
nix build .#ide-si && ./result/activate   # 两步法（构建 + 手动激活）
nix flake update            # 升级全部依赖（稳定版跟随分支点，构建命中镜像缓存）
nix fmt                     # treefmt 一键格式化（nixfmt + statix）
nix flake check             # 6 项门禁：格式 + 镜像一致性 + 机器集合 + 全目标 eval + scan 导入 + rustdesk 注入器
```
