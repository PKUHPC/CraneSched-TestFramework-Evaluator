#!/bin/bash

# Full dynamic linked Crane deployment
# Tested on Rocky Linux 9.3

set -eo pipefail

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

# Dependency for libcgroup
dnf install -y bison flex systemd-devel || {
    echo "Error installing dependency" && exit 1
}

# Ensure the installation can be found
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# Check if libcgroup is already installed
if pkg-config --exists libcgroup; then
    echo "libcgroup is already installed."
else
    if [ ! -f "libcgroup-3.1.0.tar.gz" ]; then
        setp
        wget https://github.com/libcgroup/libcgroup/releases/download/v3.1.0/libcgroup-3.1.0.tar.gz || {
            echo "Error downloading libcgroup" && exit 1
        }
        unsetp
    fi

    tar -xzf libcgroup-3.1.0.tar.gz && pushd libcgroup-3.1.0
    (./configure --prefix=/usr/local && make -j && make install) || {
        echo "Error compiling libcgroup" && exit 1
    }
    popd
fi

# Install dependencies and toolchain for Crane
dnf install -y \
    patch \
    ninja-build \
    openssl-devel \
    pam-devel \
    zlib-devel \
    libatomic \
    libstdc++-static \
    libtsan \
    libaio \
    libaio-devel || {
    echo "Error installing toolchain and dependency for craned" && exit 1        
}
# libstdc++-static libatomic for debug
# libtsan for CRANE_THREAD_SANITIZER

# Check if cmake version is higher than 3.24
required_version="3.24"
install_version="3.28.1"
download_url="https://github.com/Kitware/CMake/releases/download/v${install_version}/cmake-${install_version}-linux-x86_64.sh"

current_version=$(cmake --version 2>/dev/null | awk 'NR==1{print $3}')

if [[ -z "$current_version" ]] || [[ "$(printf '%s\n' "$current_version" "$required_version" | sort -V | head -n1)" != "$required_version" ]]; then
    echo "Installing cmake ${install_version}..."
    setp
    wget -O cmake-install.sh "$download_url" || { echo "Error downloading cmake"; exit 1; }
    bash cmake-install.sh --skip-license --prefix=/usr/local || { echo "Error installing cmake"; exit 1; }
    rm cmake-install.sh
    unsetp
else
    echo "Current cmake version ($current_version) meets the requirement."
fi

# Clone the repository
setp
if [ ! -d "CraneSched" ]; then
    git clone https://github.com/PKUHPC/CraneSched.git || {
        echo "Error cloning CraneSched" && exit 1
    }
fi

pushd CraneSched
git fetch && git pull
git checkout dev/split_embeddedDb || {
    echo "Error checking out branch dev/split_embeddedDb" && exit 1
}
unsetp

BUILD_DIR=cmake-build-release
mkdir -p $BUILD_DIR && pushd $BUILD_DIR

if [ -f "/opt/rh/gcc-toolset-13/enable" ]; then
    echo "Enable gcc-toolset-13"
    source /opt/rh/gcc-toolset-13/enable
fi

setp
cmake --fresh -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_UNQLITE=ON \
    -DENABLE_BERKELEY_DB=OFF \
    -DCRANE_USE_GITEE_SOURCE=OFF \
    -DCRANE_FULL_DYNAMIC=ON .. || {
    echo "Error configuring with cmake" && exit 1
}
unsetp

cmake --build . --clean-first || {
    echo "Error building" && exit 1
}

popd
popd
