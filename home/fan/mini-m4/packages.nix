# mini-m4 专属命令行工具
{ pkgs, ... }:
{
  home.packages = [
    # MinIO 客户端（二进制名 mc）：发版产物上传 hcs 桶用，见 hc-sh-app/hc-flutter/scripts/minio-upload.sh
    pkgs.minio-client
  ];
}
