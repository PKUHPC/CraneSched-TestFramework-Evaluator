#!/bin/bash

# 测试一组 Slurm 命令的执行时间

# 定义一组要测试的命令
commands=("sinfo" "squeue" "sacct" "scontrol show nodes" "sacctmgr list stat")

# 提交大量任务
# sbatch --array=1-100 --spread-job test.job

# 循环遍历并测试每个命令
for cmd in "${commands[@]}"
do
    echo "Testing execution time for command: $cmd"
    time $cmd > /dev/null
    echo "----------------------------------------"
done

# 测试提交/取消小任务
echo "Testing execution time for command: sbatch"
time sbatch_output=$(sbatch --array=1 test.job)

# 从sbatch输出中提取作业ID
job_id=$(echo $sbatch_output | grep -oP '(?<=Submitted batch job )\d+')

echo "Job ID is $job_id"
echo "----------------------------------------"

# 测试scancel命令
echo "Testing execution time for command: scancel"
time scancel $job_id
echo "----------------------------------------"

# 测试完毕
echo "All tests completed."
