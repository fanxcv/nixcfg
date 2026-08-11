# 仓库根相对路径 → 绝对路径（组装清单里用，避免 ../../ 相对路径混乱）
# 用法：tools.relative "home/fan/_common_"
{ self }:
path: self + "/" + path
