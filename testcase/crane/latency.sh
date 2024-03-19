#!/bin/bash

# Script for testing the latency of Crane commands
# This should be run under testcase/crane directory

# Submit payload
if [ $# -ne 1 ]; then
    echo "Usage: $0 <payload_num>"
    exit 1
fi

PAYLOADNUM=$1

if [ $PAYLOADNUM -gt 0 ]; then
    cbatch --repeat $PAYLOADNUM long_test.job &> /dev/null || { echo "Error submiting payload, quitting"; exit 1; }
    sleep 3
else
    echo "Payload number less than 1, skipping submission"
fi

# Define commands to test
commands=("cinfo" "cqueue -m 100000" "cacct -m 100000" "ccontrol show node" "cacctmgr show account")
for cmd in "${commands[@]}"
do
    echo "Testing execution time for command: $cmd"
    { time $cmd; } 2>&1 1>/dev/null
    echo "----------------------------------------"
done

# Test cbatch/ccancel by submitting/cancelling a sample job
echo "Testing execution time for command: cbatch"
{ time cbatch_output=$(cbatch long_test.job); } 2>&1 1>/dev/null

task_id=$(echo $cbatch_output | grep -oP '(?<=Task Id allocated: )\d+')

echo "Job ID is $task_id"
echo "----------------------------------------"

echo "Testing execution time for command: ccancel"
{ time ccancel $task_id; } 2>&1 1>/dev/null
echo "----------------------------------------"

echo "All tests completed."