#! /bin/bash

# if needed
# export http_proxy=http://xcat:17890
# export https_proxy=http://xcat:17890

if [ ! -d "mininet" ]; then
    git clone https://github.com/mininet/mininet.git || {
        echo "Error cloning Mininet" && exit 1
    }
fi

dnf install -y help2man python-pip centos-release-nfv-openvswitch

sh mininet/util/install.sh -nfv
systemctl start openvswitch
systemctl enable openvswitch

mkdir -p /etc/network
echo "iface nat0-eth0 inet manual" > /etc/network/interfaces
