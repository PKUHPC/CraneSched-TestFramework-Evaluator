#!/bin/bash

# OpenPBS installer for Rocky Linux 9 

set -eo pipefail

# Set to 1 to treat the current node as the head node
HEAD=0
HEADSERVER="l11c58n2"
if [ $HEAD -eq 1 ]; then
    HEADSERVER=$(hostname)
fi

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

# Install dependencies
dnf install -y dnf-plugins-core || { echo "Failed to install dnf-plugins-core"; exit 1; }
dnf config-manager --enable crb || { echo "Failed to enable CRB repository"; exit 1; }

dnf install -y gcc make rpm-build libtool hwloc-devel \
    libX11-devel libXt-devel libedit-devel libical-devel \
    ncurses-devel perl postgresql-devel postgresql-contrib python3-devel tcl-devel \
    tk-devel swig expat-devel openssl-devel libXext libXft \
    autoconf automake gcc-c++ cjson-devel || { echo "Failed to install necessary packages"; exit 1; }

dnf install -y expat libedit postgresql-server postgresql-contrib python3 \
    sendmail sudo tcl tk libical chkconfig cjson || { echo "Failed to install additional packages"; exit 1; }

# Download OpenPBS master zip
if [ ! -f openpbs-master.zip ]; then
    echo "openpbs-master.zip does not exist, downloading..."
    setp
    curl -L https://github.com/openpbs/openpbs/archive/refs/heads/master.zip -o openpbs-master.zip || { echo "Failed to download OpenPBS master.zip"; exit 1; }
    unsetp
else
    echo "openpbs-master.zip already exists, skipping download."
fi

unzip openpbs-master.zip || { echo "Failed to unzip OpenPBS master.zip"; exit 1; }
cd openpbs-master || { echo "Failed to change directory to openpbs-master"; exit 1; }

# Configure and install OpenPBS
./autogen.sh || { echo "autogen.sh failed"; exit 1; }

./configure --prefix=/opt/pbs || { echo "Configuration failed"; exit 1; }

make -j$(nproc) || { echo "Make failed"; exit 1; }

make install || { echo "Make install failed"; exit 1; }

# Post installation procedure
/opt/pbs/libexec/pbs_postinstall || { echo "PBS postinstall script failed"; exit 1; }
chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp || { echo "Failed to change permissions"; exit 1; }

echo "OpenPBS installed. Proceeding with /etc/pbs.conf configuration."

# Configuration of /etc/pbs.conf
file="/etc/pbs.conf"

if [ $HEAD -eq 0 ]; then
    echo "Configuring $file for PBS_MOM..."

    if [ -f "$file" ]; then
        sed -i "s/^PBS_SERVER=.*/PBS_SERVER=$HEADSERVER/" $file
        sed -i "s/^PBS_START_SERVER=.*/PBS_START_SERVER=0/" $file
        sed -i "s/^PBS_START_SCHED=.*/PBS_START_SCHED=0/" $file
        sed -i "s/^PBS_START_COMM=.*/PBS_START_COMM=0/" $file
        sed -i "s/^PBS_START_MOM=.*/PBS_START_MOM=1/" $file

        echo "PBS configuration updated for PBS_MOM."
    else
        echo "$file does not exist. Ensure OpenPBS was installed correctly."
    fi
fi
