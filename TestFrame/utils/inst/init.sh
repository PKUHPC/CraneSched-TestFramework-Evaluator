#!/bin/bash

# Script for Testing Preparation on Rocky Linux 9.3

# Exit on error
set -e

# Mirrors
sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
    -i.bak \
    /etc/yum.repos.d/rocky-extras.repo \
    /etc/yum.repos.d/rocky.repo
dnf update -y
dnf install -y epel-release
sed -e 's!^metalink=!#metalink=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.tuna.tsinghua.edu.cn/epel!g' \
    -e 's!https\?://download\.example/pub/epel!https://mirrors.tuna.tsinghua.edu.cn/epel!g' \
    -i /etc/yum.repos.d/epel{,-testing}.repo
dnf install -y --allowerasing yum-utils curl unzip pdsh
dnf config-manager --set-enabled crb
dnf makecache

# Toolchain
dnf install -y \
    libstdc++-devel \
    libstdc++-static \
    gcc-toolset-13 \
    llvm-toolset \
    git \
    which \
    patch \
    flex \
    bison \
    ninja-build

# Set proxy if needed
export http_proxy=http://jump:17890
export https_proxy=http://jump:17890

# Cmake
curl -L https://github.com/Kitware/CMake/releases/download/v3.28.3/cmake-3.28.3-linux-x86_64.sh -o /tmp/cmake-install.sh
chmod +x /tmp/cmake-install.sh
/tmp/cmake-install.sh --prefix=/usr/local --skip-license
rm /tmp/cmake-install.sh

# libcgroup
dnf install -y \
    openssl-devel \
    zlib-devel \
    pam-devel \
    libaio-devel \
    systemd-devel
curl -L https://github.com/libcgroup/libcgroup/releases/download/v3.1.0/libcgroup-3.1.0.tar.gz -o /tmp/libcgroup.tar.gz
tar -C /tmp -xzf /tmp/libcgroup.tar.gz
cd /tmp/libcgroup-3.1.0
./configure --prefix=/usr/local
make -j$(nproc)
make install
rm -rf /tmp/libcgroup-3.1.0 /tmp/libcgroup.tar.gz
echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH' >> /etc/profile.d/extra.sh
