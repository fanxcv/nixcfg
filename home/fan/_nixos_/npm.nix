# NixOS 真机的 node 来自 nix store（_common_/base.nix 的 pkgs.nodejs，只读），
# npm 的 global prefix 默认解析成该 store 路径 → `npm install -g` 报 ENOENT
# （无法 mkdir <store>/lib），fpi-install 装 pi / @beads/bd 即栽在此。
# mise 提供 node 的机器（darwin / ide 容器）prefix 指向 mise 安装目录，可写，无此病。
# 故本层把 npm 全局安装重定向到 ~/.local（其 bin 目录已在 _common_/base.nix 的 sessionPath 中）。
# text 类型是 lines，与 _common_/mirrors.nix 的 ~/.npmrc 内容自动拼接（不是覆盖）。
_: {
  home.file.".npmrc".text = ''
    prefix=''${HOME}/.local
  '';
}
