# nix-pve 部署记录（2026-08-13）

> 场景：参考 tsln1998/nixcfg 的 minipc，在 Proxmox VE 上部署第一台 NixOS 真机。
> 目标：128G 虚拟盘 + KDE Plasma 6 桌面 + comin 自动部署。
> 方法：PVE cloud-init 模板（Debian 12）当跳板 + nixos-anywhere 远程安装。

## 机器与配置现状

- VM 101（nix-pve，10.2.241.98），OVMF（无 Secure Boot），4 核 8G，virtio 盘 128G
- NixOS 26.05 稳定版（用户并行切换，原部署为 26.11 unstable）
- 磁盘：boot 1G + nix 48G + persist 40G + tmpfs 根 2G（LVM 余量 ~39G）
- 桌面：KDE Plasma 6 + SDDM（Wayland），fcitx5 拼音，Noto CJK
- 应用：edge/bitwarden（rustdesk/clash 因无二进制缓存临时移除）
- comin 自动部署 active（git.fan-x.fun 私有仓库，认证走 /root/.git-credentials agenix）
- fan sudo NOPASSWD；fan 密码 hash 走 agenix（secrets/fan-password.age）

## 问题清单（按发生顺序）

### 1. Debian cloud 镜像 cloud-init 不生效
- 症状：hostname 不变、无 DHCP、root 密码未设置
- 根因：镜像里 cloud-init 服务文件存在但未 enable（multi-user.target 无链接）；genericcloud 内核还缺 IDE 驱动读不到 seed 光盘
- 修复：qemu-nbd 离线注入（root 密码/网络 DHCP/host key/SSH 公钥），systemd-networkd MAC 匹配配置，grub 加 net.ifnames=0

### 2. Secure Boot 导致 kexec 失败
- 症状：`kexec_file: Enforced kernel signature verification failed`
- 根因：创建 EFI 盘时用了 pre-enrolled-keys=1（启用 Secure Boot）
- 修复：删除 EFI 盘重建（不带 pre-enrolled-keys）

### 3. kexec 镜像下载极慢（20KB/s）
- 根因：mac 代理出口带宽有限 + GitHub release 直连被墙
- 修复：gh-proxy.com（限流恢复后 478KB/s）下载到本地，--kexec 指定

### 4. rustdesk/clash-verge-rev 无二进制缓存
- 症状：installer 里源码编译（rustdesk cargo 全链）+ libsciter 从 GitHub 下载失败
- 修复：临时移除两个包（apps.nix 注释说明，真机可 nix profile install 补装）

### 5. claude-code installCheck 死循环
- 症状：构建卡在 `claude --version`（99.7% CPU 无限跑）
- 根因：nixpkgs 的 installCheck 在 nixbld 环境（无 HOME）跑 claude --version 死循环
- 修复：claude.nix override `doInstallCheck = false`（overlay 是 npmmirror 裸二进制，构建本身无问题）

### 6. 闭包传输慢（cache.nixos.org 国际线路）
- 修复：--no-substitute-on-destination 强制从 mac 局域网传（30MB/s）

### 7. home-manager 首次激活失败
- 症状：~/.nix-profile 悬空、包不全
- 根因：部署时 age-keys.txt 未注入 → agenix 失败连锁
- 修复：chroot 手动补跑激活（nix-daemon in chroot + setpriv 以 fan 身份 + nixbld 用户/组 + devpts）

### 8. comin 首次部署（手动 rebuild）的连环坑
- fan 密码未知（agenix 明文没入库）→ grub 注入 `systemd.debug-shell=1` + QMP sendkey 进 tty9 root shell
- debug shell 是 sh 且 PATH 极简（/bin 只有 sh）→ 脚本用 bash 内置 `set --` glob 定位 store 工具
- nix-daemon fetch 缺 git CLI → `systemctl set-environment PATH` + restart daemon
- GitHub 源码拉取被墙 → root git config 配代理 10.2.236.20:7890
- 闭包下载慢 → root nix.conf 配 USTC（并固化到配置 `nix.settings.substituters`）
- claude-code overlay hash 过期（26.05 版本 2.1.223）→ 更新 overlays/claude-code.nix linux-x64 hash
- .oh-my-zsh 挂载点 rm 失败（bind mount）→ 手动 clone + chown
- .secrets 未持久化 → age 私钥重启丢 → agenix 解密失败 → comin 认证失败 → immutable.nix 加 .secrets 持久化
- fan authorized_keys 被 ssh.nix 激活覆盖（拉取集合不含 mac id_rsa）→ PVE 挂载 persist 追加

## 关键经验

1. **nixos-anywhere 流程**：kexec 镜像（gh-proxy 下载）→ remote build（installer 环境构建，需代理+git+USTC）→ disko → install。`--no-substitute-on-destination` 是局域网部署的关键加速项
2. **NixOS 的 /etc 是只读合成**：/etc/nix/nix.conf 写不了，用 /root/.config/nix/nix.conf
3. **debug-shell（tty9）是无认证 root 入口**：grub linux 行加 systemd.debug-shell=1，QMP sendkey ctrl-alt-f9 进入；适合密码死锁时的 rescue
4. **impermanence bind mount 陷阱**：持久化目录是 bind mount，rm 挂载点目录会导致 inode 错乱；清内容用 find -delete，不删目录本身
5. **agenix 解密发生在系统激活**：age-keys.txt 必须持久化（home.persistence 加 .secrets）
6. **国内网络三件套**：git config 代理（GitHub 源码）+ USTC substituters（二进制缓存）+ gh-proxy（release 大文件）

## 遗留项

- grub 里还有 debug-shell=1 参数（下次 rebuild 自动清除）
- rustdesk/clash-verge-rev 未装（需要时真机补装，注意 libsciter 需放行）
- claude-code 的 linux-arm64/darwin hash 可能也过期（本次只修了 linux-x64）
- NixOS 26.05 与 26.11 的差异：comin 包需用 input 自带（稳定版 nixpkgs 无）

## 重建复盘（2026-08-14 凌晨）

### 全流程耗时
| 阶段 | 耗时 | 说明 |
|---|---|---|
| 删 VM + 重建 + 引导跳板 | ~40min | 踩了 OVMF/SecureBoot/路径坑 |
| nixos-anywhere 部署 | ~2.5h | comin go-modules 被墙 → GOPROXY 注入 |
| 系统修复（密码/SSH/LVM） | ~3h | 见下 |
| **总计** | **~6h** | 首轮"所有问题已解决"的假设被打破 |

### 新问题清单（本次新增）
1. **comin go-modules 走 proxy.golang.org 被墙** → buildGoModule 的 overrideModAttrs 注入 preBuild export GOPROXY=goproxy.cn（env 注入无效，impureEnvVars 机制会覆盖）
2. **nixos-anywhere 的 USTC 注入失效**：--no-substitute-on-destination 隐含 machineSubstituters=n → 用 --disk-encryption-keys 通道直接写 installer 的 /root/.config/nix/nix.conf（substituters 覆盖式，USTC 排前）
3. **host key 0 字节**：Debian 模板清空 key 等 cloud-init 生成但没跑 → chroot ssh-keygen -A
4. **fan 密码/SSH host key 全部失效**：agenix identityPaths=/home/fan/.secrets（bind mount 晚于系统激活）→ agenix.nix 加 /persist 直连路径
5. **.oh-my-zsh bind mount rm 失败**：激活脚本 rm -rf 挂载点 → 改 find -delete
6. **SSH 公钥被 home-manager 激活覆盖**：ssh.nix 拉取源 mac.pub 是 OneDrive HTML → 内置 mac id_rsa 到仓库（mac-pub.pub）
7. **comin 认证失败**：go-git 不走 git credential.helper → 改 auth.username + access_token_path（token 去 URL 编码）
8. **LVM PV 头损坏**（VM 运行时 nbd 挂盘导致）→ 数据完好，LABELONE 位置恢复即可（LVM label 在 PV sector 1，非 sector 0！）

### 关键教训
- **严禁 VM 运行时 nbd 挂载同一盘**（本次 LVM 损坏的根源）
- macOS tar 会混入 ._* AppleDouble 文件 → 传输用 git push/pull，不用 tar
- LVM label 在 sector 1（512B 偏移），恢复时别复制到 sector 0
- 目标机源码目录直接用 git clone（comin 同仓库），不要 tar 解压

## Cloud-init 重部署复盘（2026-08-14）

> 场景：重置 VM 101，用 cloud-init 方式从头部署（双盘法），全程记录耗时。
> 结论：核心自动化（cloud-init 生效 ~2min + disko 5s + nixos-install ~16min + comin 接管）远快于
> nixos-anywhere 方案；墙钟 6.5h 的大头在镜像准备踩坑与首次激活修复。

### 新方法：双盘法（cloud-init 宿主 + 独立目标盘）

```
阶段1  cloud-init 引导（SeaBIOS + 10G cloud image 宿主盘）
         ├─ VM101: scsi0=10G cloud镜像（宿主, /dev/sda）, virtio0=128G（目标, /dev/vda）
         ├─ cloud-init 注入: nixos用户/SSH key/密码/DHCP（PVE cidata NoCloud seed）
         └─ 验证: hostname/用户/sudo/authorized_keys 全部生效（boot→SSH ~2min）
阶段2  disko + nixos-install（SSH 内执行, ~16min）
         ├─ /root/.config/nix/nix.conf 配 USTC substituters
         ├─ disko 分区 /dev/vda（LVM: boot 1G/nix 48G/persist 40G, 5s）
         ├─ age 私钥 → /mnt/persist/home/fan/.secrets/age-keys.txt（agenix 激活必需）
         ├─ git clone 仓库（git.fan-x.fun 凭据）→ /persist/etc/nixos
         └─ HTTPS_PROXY=10.2.236.20:7890 nixos-install --flake .#nix-pve --root /mnt
             闭包走 USTC（~2.5GB），github inputs（nixpkgs/agenix/comin）走代理
阶段3  换盘启动（PVE 操作）
         ├─ shutdown → detach scsi0 → bios=ovmf + efidisk0 → boot order=virtio0
         └─ 128G 盘（virtio-blk, /dev/vda）与仓库 disks.nix 完全一致，零配置修改
阶段4  comin 接管（自动验证）
         └─ push 修复 commit → comin 自动 build+switch → Deployment succeeded
```

### 本次新问题（按发生顺序）

1. **官方 cloud image 已不可得**：channels.nixos.org 的 qcow2 404、hydra release-26.05 的
   openstack_image job 已移除、nix-community/nixos-images 只发 netboot/kexec/iso
   → PVE 装 Determinate Nix（Debian 13 支持），用 nixpkgs 源码（USTC 通道 rev 恰与
   flake.lock 同 commit 9f78f44a8794）自建 openstack 镜像（make-disk-image, ~13min）
2. **官方 openstack 镜像不用 cloud-init**：openstack-config.nix 是自家 metadata fetcher
   （OpenStack JSON 格式），不认 PVE 的 NoCloud cidata → 自建时去掉 openstack-config.nix，
   换成 services.cloud-init.enable = true + default_user=nixos + NixOS DHCP
3. **镜像 initrd 缺 virtio 驱动**：没导入 qemu-guest profile → 盘认不出 → systemd
   emergency（Timed out waiting for /dev/disk/by-label/nixos）→ 补
   boot.initrd.availableKernelModules = [virtio_pci virtio_scsi virtio_blk virtio_net]
4. **home-manager 首次激活失败**：/persist/home/fan 是 root 所有（scp 注入 age 私钥时
   创建的），hm-activate 写 /home/fan/.nix-profile.lock Permission denied
   → VM 停止后 qemu-nbd + vgchange -ay 挂 /persist，chown -R 1000:100（本次仅此一处
   home-manager 失败，无上次的 nix-daemon/oh-my-zsh/ssh 覆盖连锁）
5. **nix-pve 配置暴露 bug**：shells.nix envExtra 写死 . /nix/var/nix/profiles/default/
   etc/profile.d/nix.sh（darwin/容器路径），NixOS 无此路径 → zsh 每次启动报错
   → 按 platform 跳过（commit 23346af，comin 自动部署修复）

### 关键经验

1. **virtio-scsi → /dev/sdX，virtio-blk → /dev/vdX**：目标盘挂 virtio0 可零修改复用
   仓库 disks.nix；宿主盘用 scsi0 避免盘名冲突
2. **nixos-install 的闭包直进 /mnt/nix**（--store 语义），宿主 /nix 只需放工具，
   宿主盘 10G 足够，无需预热构建
3. **age 私钥必须在 nixos-install 前放进 /mnt/persist/home/fan/.secrets/**，且 owner
   要是 fan（root 会导致 hm 激活失败）
4. **USTC nix-channels 的 git-revision 与 flake.lock 对齐时可零网络风险拉源码**：
   nixexprs.tar.xz（40MB）即 nixpkgs 完整源码
5. **flake inputs 走 HTTPS_PROXY 代理**（github tarball），闭包走 USTC——nixos-install
   前 export 即可，无需改系统配置
6. cloud-init 镜像自建路径：nixpkgs/nixos/maintainers/scripts/openstack/ 下仿
   openstack-image.nix + make-disk-image，构建机在 PVE（/root/nixpkgs + cloud-init-image.nix）

### 遗留项

- tailscale 重新登录（全新系统 Logged out）
- 镜像构建产物留存：/root/cloud-img-result2/（PVE），后续重置可直接复用
- PVE 已装 Determinate Nix（以后构建/复用镜像用）
