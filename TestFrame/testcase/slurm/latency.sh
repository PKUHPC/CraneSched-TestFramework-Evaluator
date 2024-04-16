#!/bin/bash

# Script for testing the latency of Slurm commands
# This should be run under testcase/slurm directory

# Submit payload
if [ $# -ne 1 ]; then
    echo "Usage: $0 <payload_num>"
    exit 1
fi

PAYLOADNUM=$1

if [ $PAYLOADNUM -gt 0 ]; then
    sbatch --array=1-$PAYLOADNUM long_test.job &> /dev/null || { echo "Error submiting payload, quitting"; exit 1; }
    sleep 10
else
    echo "Payload number less than 1, skipping submission"
fi

# Define commands to test
commands=("sinfo" "squeue -r" "sacct" "scontrol show node" "sacctmgr show account")
for cmd in "${commands[@]}"
do
    echo "Testing execution time for command: $cmd"
    { time $cmd; } 2>&1 1>/dev/null
    echo "----------------------------------------"
done

# Test sbatch/scancel by submitting/cancelling a sample job
echo "Testing execution time for command: sbatch"
{ time sbatch_output=$(sbatch long_test.job); } 2>&1 1>/dev/null

task_id=$(echo $sbatch_output | grep -oP '(?<=Submitted batch job )\d+')

echo "Job ID is $task_id"
echo "----------------------------------------"

echo "Testing execution time for command: scancel"
{ time scancel $task_id; } 2>&1 1>/dev/null
echo "----------------------------------------"

echo "All tests completed."
