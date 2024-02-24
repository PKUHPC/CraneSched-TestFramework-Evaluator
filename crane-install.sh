#!/bin/bash

# Full dynamic linked Crane deployment
# For Rocky Linux 9

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
    llvm-toolset \
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
pushd CraneSched
git checkout bugfix/deadlock || {
    echo "Error checking out branch bugfix/deadlock" && exit 1
}

git fetch && git pull
mkdir -p ReleaseBuild && pushd ReleaseBuild
cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS_INIT="--gcc-toolchain=/usr" \
    -DCMAKE_CXX_FLAGS_INIT="--gcc-toolchain=/usr" \
    -DENABLE_UNQLITE=ON \
    -DENABLE_BERKELEY_DB=OFF \
    -DCRANE_USE_GITEE_SOURCE=OFF .. || {
    echo "Error configuring with cmake" && exit 1
}

# mkdir -p cmake-build-debug-clang-16 && pushd cmake-build-debug-clang-16
# cmake -GNinja \
#     -DCMAKE_BUILD_TYPE=Debug \
#     -DCMAKE_C_COMPILER=clang \
#     -DCMAKE_CXX_COMPILER=clang++ \
#     -DCMAKE_C_FLAGS_INIT="--gcc-toolchain=/opt/rh/gcc-toolset-13/root/usr" \
#     -DCMAKE_CXX_FLAGS_INIT="--gcc-toolchain=/opt/rh/gcc-toolset-13/root/usr" \
#     -DENABLE_UNQLITE=ON \
#     -DENABLE_BERKELEY_DB=OFF \
#     -DCRANE_USE_GITEE_SOURCE=OFF \
#     -DCRANE_FULL_DYNAMIC=ON .. || {
#     echo "Error configuring with cmake" && exit 1
# }

cmake --build . --clean-first || {
    echo "Error building" && exit 1
}
# cmake --install . || {
#     echo "Error installing" && exit 1
# }
popd
popd
