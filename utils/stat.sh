#!/bin/bash

# 设置目录路径，如果有参数则使用参数作为路径，否则使用当前目录
DIRECTORY=${1:-.}

# 打印表格标题
echo "File Name,Creation Time"

# 遍历目录下的所有 *.out 文件
find "$DIRECTORY" -type f -name "*.out" | while read file; do
    # 获取文件的修改时间，因为并非所有系统都支持创建时间的概念
    # 这里假设stat的%y选项能提供足够精确的时间戳，包括毫秒
    creation_time=$(stat -c '%y' "$file")

    # 输出文件名和创建时间，格式为 CSV
    echo "$(basename "$file"),$creation_time"
done
