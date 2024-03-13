#!/bin/bash

# Ensure the script is run as root
if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

echo "Starting the script execution."

# Stop slurmctld and slurmdbd services
systemctl stop slurmctld && echo "slurmctld service stopped." || echo "Failed to stop slurmctld service."
systemctl stop slurmdbd && echo "slurmdbd service stopped." || echo "Failed to stop slurmdbd service."

# Reset the database
if mysql -u root -e "drop database slurm_acct_db;"; then
    echo "slurm_acct_db database dropped."
    mysql -u root -e "create database slurm_acct_db" && echo "slurm_acct_db database created."
else
    echo "Failed to drop the slurm_acct_db database."
fi

# Remove cache
if rm /var/spool/slurmctld/* -rf; then
    echo "Files in /var/spool/slurmctld deleted."
else
    echo "Failed to delete files in /var/spool/slurmctld."
fi

echo "Done."
