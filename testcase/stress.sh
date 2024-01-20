#!/bin/bash

# Print start time
echo "Start time: $(date)"

# 1s -> 100 task
# 100 * 1000 = 100,000 task

for i in {1..1000}; do
    # Submit the Slurm job in the background
    echo "[#$i]" && sbatch --array=1-100 --spread-job test.job &

    sleep 1
done

# Print end time
echo "End time: $(date)"
