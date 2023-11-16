#!/bin/bash
set -e
export MAKEFLAGS="-j$(nproc)"

# WITH_UPX=1

platform="$(uname -s)"
platform_arch="$(uname -m)"

if [ -x "$(which apt 2>/dev/null)" ]
    then
        apt update && apt install -y \
            build-essential clang pkg-config autoconf libtool libcap-dev \
            libncurses-dev git gettext bison autopoint
fi

if [ -d build ]
    then
        echo "= removing previous build directory"
        rm -rf build
fi

if [ -d release ]
    then
        echo "= removing previous release directory"
        rm -rf release
fi

# create build and release directory
mkdir build
mkdir release
pushd build

# download util-linux
git clone https://github.com/util-linux/util-linux
util_linux_version="$(cd util-linux && git describe --long --tags|sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')"
mv util-linux "util-linux-${util_linux_version}"
echo "= downloading util-linux v${util_linux_version}"

if [ "$platform" == "Linux" ]
    then
        export CFLAGS="-static"
        export LDFLAGS='--static'
    else
        echo "= WARNING: your platform does not support static binaries."
        echo "= (This is mainly due to non-static libc availability.)"
fi

echo "= building util-linux"
pushd util-linux-${util_linux_version}
env CFLAGS="$CFLAGS -g -O2 -Os -ffunction-sections -fdata-sections" ./autogen.sh
env CFLAGS="$CFLAGS -g -O2 -Os -ffunction-sections -fdata-sections" ./configure \
    --disable-w --disable-shared LDFLAGS="$LDFLAGS -Wl,--gc-sections"
make DESTDIR="$(pwd)/install" install
popd # util-linux-${util_linux_version}

popd # build

shopt -s extglob

echo "= extracting util-linux binary"
mv build/util-linux-${util_linux_version}/install/bin/* release 2>/dev/null
mv build/util-linux-${util_linux_version}/install/sbin/* release 2>/dev/null
mv build/util-linux-${util_linux_version}/install/usr/bin/* release 2>/dev/null
mv build/util-linux-${util_linux_version}/install/usr/sbin/* release 2>/dev/null

echo "= striptease"
for file in release/*
  do
      strip -s -R .comment -R .gnu.version --strip-unneeded "$file" 2>/dev/null
done

if [[ "$WITH_UPX" == 1 && -x "$(which upx 2>/dev/null)" ]]
    then
        echo "= upx compressing"
        for file in release/*
          do
              upx -9 --best "$file" 2>/dev/null
        done
fi

echo "= create release tar.xz"
[ -n "$(ls -A release/ 2>/dev/null)" ] && \
tar --xz -acf util-linux-static-v${util_linux_version}-${platform_arch}.tar.xz release
# cp util-linux-static-*.tar.xz /root 2>/dev/null

if [ "$NO_CLEANUP" != 1 ]
    then
        echo "= cleanup"
        rm -rf release build
fi

echo "= util-linux v${util_linux_version} done"
