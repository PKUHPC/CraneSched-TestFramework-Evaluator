#!/bin/bash

# Print start time
pushd crane
echo "Start time: $(date)"

# 1s -> 100 task
# 100 * 1000 = 100,000 task

for i in {1..1000}; do
    # Submit the Slurm job in the background
    echo "[#$i]" && cbatch --repeat=100 test.job &

    sleep 1
done

# Print end time
echo "End time: $(date)"
popd