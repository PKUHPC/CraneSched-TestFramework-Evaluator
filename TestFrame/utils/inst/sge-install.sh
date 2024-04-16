#!/bin/bash

# Install SGE on Rocky Linux 9.3

SGE_UID=955
EXEC_START_NOW=0

set -eo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <master|exec> [master_hostname]"
    exit 1
fi

INSTALL_MODE=$1
MASTER_HOSTNAME=${2:-$(hostname)}

# Function to set and unset proxy
setp() {
    export http_proxy=http://192.168.203.60:17890
    export https_proxy=http://192.168.203.60:17890
    git config --global http.proxy $http_proxy
    git config --global https.proxy $https_proxy
}

unsetp() {
    unset http_proxy
    unset https_proxy
    git config --global --unset http.proxy
    git config --global --unset https.proxy
}

# Dependency
echo "Installing dependencies..."
dnf group install -y "Development Tools" || { echo "Failed to install Development Tools."; exit 1; }
dnf install -y hwloc-devel libdb-devel motif-devel ncurses-devel openssl-devel pam-devel rsync systemd-devel wget || { echo "Failed to install required packages."; exit 1; }
dnf install -y https://dl.rockylinux.org/pub/rocky/9/CRB/x86_64/os/Packages/l/libtirpc-devel-1.3.3-2.el9.x86_64.rpm || { echo "Failed to install libtirpc-devel."; exit 1; }

# Check if cmake version is higher than 3.24
required_version="3.24"
install_version="3.28.1"
download_url="https://github.com/Kitware/CMake/releases/download/v${install_version}/cmake-${install_version}-linux-x86_64.sh"

current_version=$(cmake --version 2>/dev/null | awk 'NR==1{print $3}')

if [[ -z "$current_version" ]] || [[ "$(printf '%s\n' "$current_version" "$required_version" | sort -V | head -n1)" != "$required_version" ]]; then
    setp
    echo "Installing cmake ${install_version}..."
    wget -O cmake-install.sh "$download_url" || { echo "Error downloading cmake"; exit 1; }
    bash cmake-install.sh --skip-license --prefix=/usr/local || { echo "Error installing cmake"; exit 1; }
    rm cmake-install.sh
    unsetp
else
    echo "Current cmake version ($current_version) meets the requirement."
fi

echo "Dependencies installed."

# Get source from Github
if [ ! -d "sge" ]; then
    setp
    echo "Downloading source..."
    git clone https://github.com/daimh/sge.git || { echo "Failed to clone the repository."; exit 1; }
    unsetp
fi

echo "Source downloaded."

# Build and install
echo "Building & installing SGE..."
pushd sge || { echo "Failed to change directory to sge."; exit 1; }
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/opt/sge || { echo "Failed to run cmake."; exit 1; }
cmake --build build -j || { echo "Failed to build the project."; exit 1; }
cmake --install build || { echo "Failed to install the project."; exit 1; }
popd || { echo "Failed to change directory back."; exit 1; }

echo "SGE installed."

# Configure
echo "Configuring SGE..."

# Check if user `sge` exists...
id -u sge &>/dev/null || useradd -u $SGE_UID -r -d /opt/sge sge

# Configure based on the installation mode
case $INSTALL_MODE in
    master)
        chown -R sge /opt/sge
        pushd /opt/sge
        yes "" | ./install_qmaster
        source /opt/sge/default/common/settings.sh
        qconf -as $MASTER_HOSTNAME
        ;;
    exec)
        mkdir -p /opt/sge/default
        chown -R sge /opt/sge/default

        if [ -d "/opt/sge/default/common" ]; then
            echo "/opt/sge/default/common exists. Backing up and removing old directory..."
            mv /opt/sge/default/common "/opt/sge/default/common_backup_$(date +%Y%m%d_%H%M%S)"
        fi
        scp -pr $MASTER_HOSTNAME:/opt/sge/default/common /opt/sge/default/common

        if [ $EXEC_START_NOW -eq 1 ]; then
            pushd /opt/sge
            echo "Try to start execd now..." 
            yes "" | ./install_execd
            source /opt/sge/default/common/settings.sh
            qhost -q
        fi
        ;;
    *)
        echo "Invalid installation mode: $INSTALL_MODE"
        exit 1
        ;;
esac

echo "SGE configuration completed."
