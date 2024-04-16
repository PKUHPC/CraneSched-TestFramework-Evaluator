#!/bin/bash

set -eo pipefail

# 检查配置文件和节点列表文件
if [ ! -f .sync_config ]; then
    echo ".sync_config 配置文件不存在"
    exit 1
fi

# 节点列表
# if [ ! -f nodes.txt ]; then
#     echo "nodes.txt 文件不存在"
#     exit 1
# fi

# nodes=$(cat nodes.txt)
nodes="l11c58n3 l11c58n4 l11c59n1 l11c59n2 l11c59n3 l11c59n4 l11c60n1 l11c60n2 l11c60n3 l11c60n4"

# 读取配置文件并按行处理
while IFS= read -r line || [[ -n "$line" ]]; do
    # 忽略注释和空行
    [[ "$line" = \#* ]] || [[ -z "$line" ]] && continue

    # 解析配置
    IFS=':' read -r src node dest <<< "$line"

    # 处理排除项
    if [[ $src == -* ]]; then
        exclude+=("${src:1}")
        continue
    fi

    # 指定了节点则仅同步到该节点，否则同步到所有节点
    if [[ -z "$node" ]]; then
        target_nodes=($nodes)
    else
        target_nodes=($node)
    fi

    # 执行同步
    for target_node in "${target_nodes[@]}"; do
        echo "正在同步 $src 到 $target_node:$dest"
        rsync -avz --progress "${exclude[@]/#/--exclude=}" "$src" "$target_node:$dest"
    done
done < .sync_config

echo "同步完成"
