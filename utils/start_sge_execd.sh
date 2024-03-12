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

qconf -sh &> /dev/null || { echo "qconf failed, check if host added in master."; exit 1; }
yes "" | ./install_execd || { echo "Warning: something went wrong in installing execd"; }

if pgrep -a --nslist uts --ns $$ sge_execd; then
    echo "sge_execd started."
else
    echo "sge_execd not started, restart manually..."
    $SGE_BIN/sge_execd || { echo "Failed to start sge_execd" ; exit 1; }
fi

# Specifically configure queue and hostgroup
qconf -mattr queue slots [$HOSTNAME=$SLOT_NUM] $SGE_QUEUE
qconf -mattr hostgroup hostlist $HOSTNAME @allhosts

echo "sge_execd on $HOSTNAME started."
popd
