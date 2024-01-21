#!/bin/bash
rm -f *.out
rm -f slurm/*.out
rm -f slurm/result
mkdir -p slurm/result

systemctl stop slurmctld
systemctl stop slurmdbd

# Drop DB in mysql 
mysql -u root -e "drop database slurm_acct_db"
mysql -u root -e "create database slurm_acct_db"

# Remove cache 
rm /var/spool/slurmctld/* -rf
