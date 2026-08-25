# secrets/ —— age 加密 secrets 目录规约

## 目录结构（公共 vs 机器独有）

- **secrets/ 根**：公共/多机共享文件（所有机器、跨平台通用）
- **secrets/hosts/<machine>/**：机器独有文件（一个机器/部署单元一个目录）
  - 不只放公私钥：skemate 配置、lucky 归档、tailscale state 等一切机器独有物都进这里
  - 当前机器清单：`ide-lenovo` `ide-si`（ide 容器）、`mba-m5` `mbp-m1` `mini-m4`（mac）、
    `nix-pve`（NixOS 真机）、`fan` `mi`（PVE 宿主机，见 pve/）
  - 跨机器共用而非常见文件（如 comin-token 被 mini-m4/nix-pve 共用）：
    文件本体放主机器目录（nix-pve），其他机器跨引用并注释说明

## 公私钥约定（统一）

- **私钥**：`secrets/hosts/<host>/<key>.age` 加密入库（git 可提交）
- **公钥**：`<key>.pub` **明文直接入库**（不加密、不入 source/、encrypt.sh 自动跳过）
  - 消费方 nix 直接拷贝明文（如 hosts/_nixos_/base/keys.nix、home/fan/_container_/ssh-host-key.nix）
- SSH 公钥 ≠ age 公钥：age 接收者公钥集合见 `keys.nix`（`age-keygen -y ~/.secrets/age-keys.txt`）

## 当前文件清单

```
secrets/
├── age-keys.txt.age              # age 私钥备份（公共：所有机共用一把私钥）
├── ai.env.age                    # 各机激活解密（_common_/secrets.nix）
├── git-credentials.age           # ~/.git-credentials（公共）
├── headscale-auth-key.txt.age    # tailscale pre-auth key（三 mac，公共）
├── ssh-config.age                # ~/.ssh/config（mba/mbp/nix-pve，公共）
├── syncthing-gui-password.age    # syncthing GUI 密码（三 mac + nix-pve，公共）
├── encrypt.sh / keys.nix / README.md
└── hosts/
    ├── ide-lenovo/  ssh_host_ed25519_key.age + .pub（明文）
    ├── ide-si/      ssh_host_ed25519_key.age + .pub（明文）
    ├── mba-m5/      ssh_id_rsa.age + .pub
    ├── mbp-m1/      ssh_id_rsa.age + .pub
    ├── mini-m4/     bill-app-android-release.p12.age（签名密钥）
    │                skemate-config.json.age + skemate-tunnel.yaml.age
    │                ssh_id_rsa.age + .pub
    ├── nix-pve/     comin-token.age（mini-m4 共用）、fan-password.age
    │                ssh_host_ed25519_key.age + .pub（明文）
    ├── fan/         tailscale-fan-state.age
    └── mi/          tailscale-mi-state.age、lucky-data.age
```

## 加密新文件

明文统一放 `source/`（已 gitignore，结构与 secrets/ 同构——机器独有放 `source/hosts/<host>/`），
一键批量加密，接收者自动取 `keys.nix` 全部公钥：

```bash
./encrypt.sh           # 加密 source/ 下所有文件 → secrets/<同名>.age
./encrypt.sh --force   # 覆盖已存在的 .age
```

公钥 `.pub` 不加密：明文直接放 `secrets/hosts/<host>/`，encrypt.sh 自动跳过。

## 解密查看 / 更新

```bash
age -d -i ~/.secrets/age-keys.txt secrets/hosts/nix-pve/fan-password.age
```

## 启用（home-manager 侧）

1. 加密文件就位（.age 已入库）
2. `home/fan/_common_/secrets.nix` agenix 块已启用（ai.env/git-credentials）
3. 各模块自带解密：tailscale/ssh/keystore/skemate 等（见各自 .nix）
4. 私钥就位：`$HOME/.secrets/age-keys.txt`（chmod 600，**永不提交 git**）
   - 容器：compose 挂载 `./.secrets → /root/.secrets`（docker/ide/ 目录下）
   - 新机器：把私钥拷到该机 + 公钥加入 `keys.nix`

## 轮换私钥

```bash
age-keygen -o ~/.secrets/age-keys.txt.new && chmod 600 ~/.secrets/age-keys.txt.new
# 旧私钥解出所有 .age → 新公钥重新加密 → 更新 keys.nix → 替换私钥
```
