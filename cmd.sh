#! /bin/bash

dnf install epel-release -y
dnf makecache
dnf update -y
dnf install git -y
# git clone https://github.com/mininet/mininet.git
dnf --enablerepo=crb install help2man -y
dnf install python-pip -y
dnf install centos-release-nfv-openvswitch -y

# if needed
export http_proxy=http://xcat:17890
export https_proxy=http://xcat:17890

sh mininet/util/install.sh -nfv
systemctl start openvswitch
systemctl enable openvswitch

mkdir -p /etc/network
echo "iface nat0-eth0 inet manual" > /etc/network/interfaces

