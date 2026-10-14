# 机器注册表（单一事实来源）：flake.nix 的 homeConfigurations / darwinConfigurations /
# nixosConfigurations 与 packages 机器别名全部由此派生；新增机器只改这一处 + 机器目录。
# 字段：
#   kind        平台类型（darwin | nixos | container | ubuntu | pve），同时作为 home 层 platform 取值
#   system      nixpkgs 实例架构（darwin 走 nixpkgs-darwin 通道，见 flake.nix mkDarwinConfig）
#   user        homeConfiguration 归属用户（输出键为 "<user>@<机名>"）
#   alias       是否生成 nix run .#<机名> 一步部署别名
#   extraUnfree 额外 unfree 放行名单（可选，缺省为空）
{
  # --- Docker 开发容器（Ubuntu 底，aarch64-linux 原生容器）---
  ide-si = {
    kind = "container";
    system = "aarch64-linux";
    user = "fan";
    alias = true;
  };
  ide-lenovo = {
    kind = "container";
    system = "aarch64-linux";
    user = "fan";
    alias = true;
    extraUnfree = [
      "google-chrome"
      "albert"
      "wpsoffice-cn" # 桌面办公（kasmvnc.nix 的 x86_64 分支，真机架构）
    ];
  };
  ide-mac = {
    kind = "container";
    system = "aarch64-linux";
    user = "fan";
    alias = true;
    extraUnfree = [
      "google-chrome" # 仅 x86_64 分支用到；arm64 走 chromium
      "albert"
    ];
  };

  # --- 云服务器（Ubuntu 底，root 用户态 HM）---
  ali-ai = {
    kind = "ubuntu";
    system = "x86_64-linux";
    user = "root";
    alias = true;
  };
  hc-pro-pve-2 = {
    kind = "ubuntu";
    system = "x86_64-linux";
    user = "root";
    alias = true;
  };

  # --- PVE 宿主机（Debian 底，HM standalone + pve/ 系统层）---
  ds2 = {
    kind = "pve";
    system = "x86_64-linux";
    user = "fan";
    alias = true;
  };
  desktop = {
    kind = "pve";
    system = "x86_64-linux";
    user = "fan";
    alias = true;
  };
  fan = {
    kind = "pve";
    system = "x86_64-linux";
    user = "fan";
    alias = true;
  };
  hp = {
    kind = "pve";
    system = "x86_64-linux";
    user = "fan";
    alias = true;
  };
  mi = {
    kind = "pve";
    system = "x86_64-linux";
    user = "fan";
    alias = true;
  };
  razer = {
    kind = "pve";
    system = "x86_64-linux";
    user = "fan";
    alias = true;
  };

  # --- macOS 真机（nix-darwin，home-manager 内嵌）---
  mba-m5 = {
    kind = "darwin";
    system = "aarch64-darwin";
    user = "fan";
    alias = true;
  };
  mbp-m1 = {
    kind = "darwin";
    system = "aarch64-darwin";
    user = "fan";
    alias = true;
  };
  mini-m4 = {
    kind = "darwin";
    system = "aarch64-darwin";
    user = "fan";
    alias = true;
  };

  # --- NixOS 真机（无 nix run 别名，走 nixos-rebuild）---
  nix-pve = {
    kind = "nixos";
    system = "x86_64-linux";
    user = "fan";
    alias = false;
    extraUnfree = [
      "microsoft-edge"
      "libsciter"
    ];
  };
  nix-lenovo = {
    kind = "nixos";
    system = "x86_64-linux";
    user = "fan";
    alias = false;
    extraUnfree = [
      "microsoft-edge"
      "libsciter"
      "wechat"
      "qq"
    ];
  };
  # ASUS Zenbook UM5302TA，与 Windows 双系统（NixOS 占 p3 之后的 256G 空闲区）
  nix-asus = {
    kind = "nixos";
    system = "x86_64-linux";
    user = "fan";
    alias = false;
    extraUnfree = [
      "microsoft-edge"
      "libsciter"
      "wechat"
      "qq"
    ];
  };
}
