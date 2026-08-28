# skemate 部署后兜底：强制 tunnel.yaml 的 last_state=running（仅 ide-lenovo）
#   背景：容器内 /root/.config/skemate 由宿主机 compose 挂载（docker/ide/skemate/），
#         tunnel.yaml 是运行时文件，服务重启过程中 last_state 可能被写成非 running；
#         本激活在 skemateService（_container_/skemate.nix）拉起之后执行，幂等覆盖该字段。
#   仅 lenovo 需要；ide-si 保持平台层原行为（不声明本模块即不生效）。

{ lib, ... }:
{
  home.activation.skemateLastState = lib.hm.dag.entryAfter [ "skemateService" ] ''
    tunnel=/root/.config/skemate/tunnel.yaml
    if [ -f "$tunnel" ]; then
      if grep -q '^last_state:' "$tunnel"; then
        sed -i 's/^last_state:.*/last_state: running/' "$tunnel"
        echo "[skemate] tunnel.yaml last_state 已覆盖为 running"
      else
        echo "警告: $tunnel 无 last_state 字段，未覆盖"
      fi
    else
      echo "警告: $tunnel 不存在（宿主机未挂载 skemate 配置），跳过 last_state 覆盖"
    fi
  '';
}
