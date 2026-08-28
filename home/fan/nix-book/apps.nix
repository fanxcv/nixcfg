# 桌面应用（nix-book 笔记本）：微信/QQ（unfree，flake extraUnfree 已放行）+ mpv（VAAPI 硬解）
# 硬解：780M 核显 vcn 解码 ring 已就位（dmesg 验证），mpv.conf hwdec=vaapi 走核显省电
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wechat # 微信 4.x Linux
    (repos.unstable.qq) # QQ：26.05 的 3.2.29 源 URL 已死（404），unstable 3.2.32 可用（→ overlays/unstable.nix）
    mpv # 视频播放（VAAPI 硬解）
  ];

  # mpv VAAPI 硬解配置（780M：vcn_4_0_2 解码；vaapi 失败自动回退软解）
  home.file.".config/mpv/mpv.conf".text = ''
    hwdec=vaapi
    vo=gpu-next
  '';
}
