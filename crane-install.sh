#!/bin/bash

# Full dynamic linked Crane deployment
# For Rocky 9 Linux

# Proxy 
export http_proxy=http://xcat:17890
export https_proxy=http://xcat:17890

# dependency for libcgroup
dnf install -y bison flex systemd-devel || {
    echo "Error installing dependency" && exit 1
}

# ensure the installation can be found
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

# Check if libcgroup is already installed
if pkg-config --exists libcgroup; then
    echo "libcgroup is already installed."
else
    # Download and install libcgroup
    if [ ! -f "libcgroup-3.1.0.tar.gz" ]; then
        wget https://github.com/libcgroup/libcgroup/releases/download/v3.1.0/libcgroup-3.1.0.tar.gz || {
            echo "Error downloading libcgroup" && exit 1
        }
    fi

    tar -xzf libcgroup-3.1.0.tar.gz && pushd libcgroup-3.1.0
    (./configure --prefix=/usr/local  && make -j && make install) || {
        echo "Error compiling libcgroup" && exit 1
    }
    popd
fi

# dependency and toolchain for Crane
dnf install -y patch \
    ninja-build \
    openssl-devel \
    pam-devel \
    zlib-devel \
    libaio \
    libaio-devel || {
    echo "Error installing toolchain and dependency for craned" && exit 1        
}

# Check if cmake version is higher than 3.24
required_version="3.24"
install_version="3.28.1"
download_url="https://github.com/Kitware/CMake/releases/download/v${install_version}/cmake-${install_version}-linux-x86_64.sh"

current_version=$(cmake --version 2>/dev/null | awk 'NR==1{print $3}')

if [[ -z "$current_version" ]] || [[ "$(printf '%s\n' "$current_version" "$required_version" | sort -V | head -n1)" != "$required_version" ]]; then
    echo "Installing cmake ${install_version}..."
    wget -O cmake-install.sh "$download_url" || { echo "Error downloading cmake"; exit 1; }
    bash cmake-install.sh --skip-license --prefix=/usr/local || { echo "Error installing cmake"; exit 1; }
    rm cmake-install.sh
else
    echo "Current cmake version ($current_version) meets the requirement."
fi

# clone
if [ ! -d "CraneSched" ]; then
    git clone https://github.com/PKUHPC/CraneSched.git || {
        echo "Error cloning CraneSched" && exit 1
    }
fi
mkdir -p CraneSched/build && pushd CraneSched/build
cmake -GNinja \
    -DCRANE_FULL_DYNAMIC=ON \
    -DCRANE_USE_GITEE_SOURCE=OFF .. || {
    echo "Error cmake" && exit 1
}
cmake --build . || {
    echo "Error building" && exit 1
}
cmake --install . || {
    echo "Error installing" && exit 1
}
popd
