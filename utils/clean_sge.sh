#!/bin/bash

# Usage: ./clean_sge.sh [master|exec]
# Script for resetting SGE system

# Default configurations
SGE_ROOT="/opt/sge"
SGE_CELL="default"
MASTER_HOSTNAME=$(hostname)

if [ $# -lt 1 ]; then
    echo "Usage: $0 master|exec [master_hostname]"
    exit 1
fi

# Determine mode
INSTALL_MODE=$1
if [ "$INSTALL_MODE" == "exec" ] && [ $# -eq 2 ]; then
    MASTER_HOSTNAME=$2
else
    MASTER_HOSTNAME=$(hostname)
fi

# Check if SGE_ROOT directory exists
if [ ! -d "$SGE_ROOT" ]; then
    echo "Error: SGE root directory $SGE_ROOT does not exist."
    exit 1
fi

# Remove the SGE cell directory with error checking
if [ -d "$SGE_ROOT/$SGE_CELL" ]; then
    echo "Removing existing cell..."
    rm -rf "$SGE_ROOT/$SGE_CELL" || { echo "Failed to remove $SGE_ROOT/$SGE_CELL"; exit 1; }
fi

# Reconfigure based on the installation mode
case $INSTALL_MODE in
    master)
        echo "Stopping service..."
        systemctl stop sgemaster &> /dev/null

        pushd $SGE_ROOT
        yes "" | ./install_qmaster || { echo "Failed to install qmaster"; popd; exit 1; }
        source "$SGE_ROOT/$SGE_CELL/common/settings.sh" || { echo "Failed to source settings.sh"; popd; exit 1; }
        qconf -as $MASTER_HOSTNAME || { echo "Failed to add $MASTER_HOSTNAME to administrative hosts"; popd; exit 1; }
        popd
        ;;
    exec)
        echo "Stopping service..."
        systemctl stop sgeexecd &> /dev/null

        pushd $SGE_ROOT
        mkdir -p $SGE_ROOT/$SGE_CELL
        if [ -d "$SGE_ROOT/$SGE_CELL/common" ]; then
            echo "$SGE_ROOT/$SGE_CELL/common exists. Backing up and removing old directory..."
            mv $SGE_ROOT/$SGE_CELL/common "$SGE_ROOT/$SGE_CELL/common_backup_$(date +%Y%m%d_%H%M%S)"
        fi

        echo "Pulling conf from master..."
        scp -pr $MASTER_HOSTNAME:$SGE_ROOT/$SGE_CELL/common $SGE_ROOT/$SGE_CELL/common || exit 1
        chown -R sge:sge $SGE_ROOT/$SGE_CELL
        popd
        ;;
    *)
        echo "Invalid mode: $INSTALL_MODE"
        exit 1
        ;;
esac

echo "SGE configuration reinstalled."
