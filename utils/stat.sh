#!/bin/bash

# 设置目录路径，如果有参数则使用参数作为路径，否则使用当前目录
DIRECTORY=${1:-.}

# 打印表格标题
echo "File Name,Creation Time"

# 遍历目录下的所有 *.out 文件
# find "$DIRECTORY" -maxdepth 1 -type f -name "*.o*.*" | while read file; do
find "$DIRECTORY" -maxdepth 1 -type f -name "*.o*" | while read file; do
    # 获取文件的修改时间
    creation_time=$(stat -c '%y' "$file")

    # 输出文件名和修改时间，格式为 CSV
    echo "$(basename "$file"),$creation_time"
done
