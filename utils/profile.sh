#!/bin/bash

# 检查是否传入了足够的参数
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <PID> <output_file_path>"
    exit 1
fi

# 从命令行参数获取 PID 和输出文件路径
PID=$1
OUTPUT_FILE=$2

# 设置监控频率（以秒为单位）
INTERVAL=5

# 写入文件的头部信息
echo "Timestamp, %CPU, RSS(MB), Swap(KB)" | tee "$OUTPUT_FILE"

# 开始监控进程
while true; do
  # 使用 ps 命令获取 %CPU 和 RSS
  CPU_RSS=$(ps -p "$PID" -o %cpu,rss | tail -n +2 | awk -v OFS=, -v ORS='' '{print $1, $2/1024}')
  
  # 获取 Swap 使用量
  SWAP=$(awk '/VmSwap/ {print $2}' /proc/"$PID"/status)

  # 检查 Swap 信息是否为空，如果为空则置为0
  SWAP=${SWAP:-0}

  # 组合输出信息，包括时间戳、CPU 使用率、RSS 和 Swap 使用量
  echo "$(date '+%Y-%m-%d %H:%M:%S'),$CPU_RSS,$SWAP" | tee -a "$OUTPUT_FILE"
  
  sleep $INTERVAL
done

