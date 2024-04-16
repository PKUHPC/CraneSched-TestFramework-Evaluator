#/bin/bash

# Usage: ./start_sge_execd.sh
# Wrapper for starting sge_execd with the given configuration.

# Default configurations
HOSTNAME=$(hostname)
SGE_ROOT="/opt/sge"
SGE_CELL="default"
SGE_BIN="/opt/sge/bin/lx-amd64"
SGE_QUEUE="all.q"

# Resource
SLOT_NUM=4

pushd $SGE_ROOT
chown -R sge:sge $SGE_ROOT/$SGE_CELL
source "$SGE_ROOT/$SGE_CELL/common/settings.sh" || { echo "Failed to source settings.sh"; popd; exit 1; }

echo "Start configuring exec..." 
sleep $((RANDOM % 10 + 1))

# Initialize attempt counter
attempt=0
installed=0
configured=0
MAX_RETRY=5

while true; do
    ((attempt++))
    if (( attempt > MAX_RETRY )); then
        echo "Failed to install execd after $MAX_RETRY attempts. Exiting."
        exit 1
    fi

    if [[ $installed -ne 1 ]]; then
        # Install execd
        yes "" | ./install_execd || echo "Warning: something went wrong in installing execd."
        
        if pgrep -a --nslist uts --ns $$ sge_execd; then
            echo "sge_execd started."
            installed=1
        else
            echo "sge_execd not started, restart manually..."
            $SGE_BIN/sge_execd && installed=1 || { echo "Failed to start sge_execd"; installed=0; }
        fi
    fi

    if [[ $installed -eq 1 && $configured -ne 1 ]]; then
        # Specifically configure queue and hostgroup
        qconf -mattr queue slots [$HOSTNAME=$SLOT_NUM] $SGE_QUEUE && configured=1 || configured=0
        qconf -mattr hostgroup hostlist $HOSTNAME @allhosts && configured=1 || configured=0
    fi

    if [[ $installed -eq 1 && $configured -eq 1 ]]; then
        break
    fi

    wait_time=$((RANDOM % 10 + 1))
    echo "Attempt $attempt failed, retrying in $wait_time seconds..."
    sleep $wait_time
done

echo "sge_execd on $HOSTNAME started."
popd
