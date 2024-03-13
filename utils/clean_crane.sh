#!/bin/bash

# 检查参数数量
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 mode(1:acct_table | 2:qos_table | 3:task_table | 4:user_table | 5:all | 6:acct_table+qos_table+user_table)"
    echo "Parameter error: please input mode num!"
    exit 1
fi

mode=$1

# 读取配置文件中的账号密码以及unqlite文件路径
confFile=/etc/crane/database.yaml
username=$(grep 'DbUser' "$confFile" | awk '{print $2}' | tr -d '"')
password=$(grep 'DbPassword' "$confFile" | awk '{print $2}' | tr -d '"')
embedded_db_path=$(grep 'CraneCtldDbPath' "$confFile" | awk '{print $2}')
parent_dir="${embedded_db_path%/*}"
env_path="${parent_dir}/CraneEnv"

# MongoDB服务器的地址和端口
host="localhost"
port="27017"

# 使用mongo shell连接到MongoDB服务器并清空指定的集合
function wipe_collection() {
    if ! mongosh --username "$username" --password "$password" --host "$host" --port "$port" --eval "use crane_db; db.$1.deleteMany({});" ; then
        echo "Failed to wipe collection $1"
        exit 1
    fi
}

# 根据模式清空集合并处理文件
case "$mode" in
    1|5|6) wipe_collection acct_table ;;
    2|5|6) wipe_collection qos_table ;;
    3|5) 
        wipe_collection task_table
        [[ -e "$embedded_db_path" ]] && echo "Removing file $embedded_db_path ..." && rm "$embedded_db_path"
        [[ -e "$env_path" ]] && echo "Removing env folder $env_path ..." && rm -rf "$env_path"
        ;;
    4|5|6) wipe_collection user_table ;;
    *)
        echo "Invalid mode: $mode"
        exit 1
        ;;
esac

echo "Done."
