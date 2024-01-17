#!/bin/bash
#SBATCH --ntasks-per-node 1
#SBATCH --nodes 1
#SBATCH -c 1
#SBATCH --mem 5M
#SBATCH -o slurm/%j.out
#SBATCH -p compute
#SBATCH -J Slurm_Test

echo "Hello world! Current PID $$"
#for i in {11..14} ; do ssh "cn$i" echo "Pam Test\!" ; done
#pwd
sleep 100
echo "done"
