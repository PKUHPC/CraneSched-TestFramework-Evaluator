#!/bin/bash

# Print start time
echo "Start time: $(date)"

# 1s -> 10000 task
# 1000 * 10000 = 10,000,000 task

for i in {1..1000}; do
    # Submit the Slurm job in the background
    echo "[#$i]" && sbatch --array=1-10000 test.job &

    sleep 1
done

# Print end time
echo "End time: $(date)"
