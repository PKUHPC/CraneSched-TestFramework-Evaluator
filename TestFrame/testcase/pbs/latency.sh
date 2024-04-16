#!/bin/bash

# Script for testing the latency of PBS commands
# This should be run under testcase/pbs directory

# Submit payload
if [ $# -ne 1 ]; then
    echo "Usage: $0 <payload_num>"
    exit 1
fi

PAYLOADNUM=$1

if [ $PAYLOADNUM -gt 0 ]; then
    qsub -J 1-$PAYLOADNUM long_test.job &> /dev/null || { echo "Error submiting payload, quitting"; exit 1; }
    sleep 3
else
    echo "Payload number less than 1, skipping submission"
fi

# Define commands to test 
# No "cacctmgr show account" equivalent in PBS
commands=("pbsnodes -aSj" "qstat -t 35[]" "qstat -tH" "pbsnodes -a" )
for cmd in "${commands[@]}"
do
    echo "Testing execution time for command: $cmd"
    { time $cmd; } 2>&1 1>/dev/null
    echo "----------------------------------------"
done

# Test qsub/qdel by submitting/cancelling a sample job
echo "Testing execution time for command: qsub"
{ time qsub_output=$(qsub long_test.job); } 2>&1 1>/dev/null

# Extract the job ID (assuming PBS outputs the job ID in a standard format like 123.server)
task_id=$(echo "$qsub_output" | grep -oP '^\d+')

echo "Job ID is $task_id"
echo "----------------------------------------"

echo "Testing execution time for command: qdel"
{ time qdel $task_id; } 2>&1 1>/dev/null
echo "----------------------------------------"

echo "All tests completed."
