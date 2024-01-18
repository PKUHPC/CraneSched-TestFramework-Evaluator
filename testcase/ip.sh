#!/bin/bash
#SBATCH -o job.%j.out
#SBATCH -p compute
#SBATCH -J IPTest
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=1

ip -4 a
sleep 10
echo "done"
