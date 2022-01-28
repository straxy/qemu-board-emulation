#!/bin/bash

QEMU_VER=6.1.0
TOOLCHAIN_VER=10.3-2021.07
UBOOT_VER=2021.04
LINUX_VER=5.14.3

# Global definitions
PROJDIR_PATH=$PWD
ENVFILE=env.sh

set -e

if [ `id -u` -eq 0 ]; then
   echo "Must run as regular user"
   exit
fi

function check_existing
{
    if [ "$1" = "clean" ]; then
        echo "Deleting old installation"
        rm -rf ${PROJDIR_PATH}/qemu
        rm -rf ${PROJDIR_PATH}/u-boot
        rm -rf ${PROJDIR_PATH}/linux
        rm -rf ${PROJDIR_PATH}/gcc-arm-${TOOLCHAIN_VER}-x86_64-arm-none-linux-gnueabihf
        rm -rf $ENVFILE
    else
        if [ -f $ENVFILE ]; then
            echo "Detected previous installation, aborting."
            echo "Pass 'clean' if you want to refresh installation."
            exit
        fi
    fi
}

function build_qemu
{
    echo "Installing prerequisites ..."
    sudo apt -y install git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev \
        libnfs-dev libiscsi-dev git-email libaio-dev libbluetooth-dev \
        libbrlapi-dev libbz2-dev libcap-dev libcap-ng-dev libcurl4-gnutls-dev \
        libgtk-3-dev libibverbs-dev libjpeg8-dev libncurses5-dev libnuma-dev \
        librbd-dev librdmacm-dev libsasl2-dev libsdl2-dev libseccomp-dev \
        libsnappy-dev libssh2-1-dev libvde-dev libvdeplug-dev libxen-dev \
        liblzo2-dev valgrind xfslibs-dev kpartx libssl-dev net-tools \
        python3-sphinx libsdl2-image-dev flex bison libgmp3-dev libmpc-dev \
        device-tree-compiler u-boot-tools bc git libncurses5-dev lzop make \
        tftpd-hpa uml-utilities nfs-kernel-server swig ninja-build libusb-1.0-0-dev
    echo "                         ... done"

    echo "Downloading QEMU ..."
    wget -c https://download.qemu.org/qemu-${QEMU_VER}.tar.xz
    tar xf qemu-${QEMU_VER}.tar.xz
    mv qemu-${QEMU_VER} qemu
    echo "                 ... done"

    echo "Building QEMU ..."
    pushd ${PROJDIR_PATH}/qemu
    mkdir -p bin/arm
    pushd bin/arm
    ../../configure --target-list=arm-softmmu \
                    --enable-sdl \
                    --enable-tools \
                    --enable-fdt \
                    --enable-libnfs \
                    --audio-drv-list=alsa
    make -j4

    export PATH=${PWD}/arm-softmmu:$PWD:$PATH

    # Update env.sh
tee ${PROJDIR_PATH}/${ENVFILE} << EOF
# global defines
export PROJDIR_PATH=${PROJDIR_PATH}

# build defines
export QEMU_PATH=${PWD}/arm-softmmu
export QEMU_TOOLS_PATH=${PWD}

# PATH update
export PATH=\${QEMU_PATH}:\${QEMU_TOOLS_PATH}:\$PATH
EOF
    popd; popd
    echo "               ... done"
}

function get_toolchain
{
    echo "Getting toolchain ..."
    wget -c https://developer.arm.com/-/media/Files/downloads/gnu-a/${TOOLCHAIN_VER}/binrel/gcc-arm-${TOOLCHAIN_VER}-x86_64-arm-none-linux-gnueabihf.tar.xz
    tar xf gcc-arm-${TOOLCHAIN_VER}-x86_64-arm-none-linux-gnueabihf.tar.xz

    export PATH=${PWD}/gcc-arm-${TOOLCHAIN_VER}-x86_64-arm-none-linux-gnueabihf/bin:$PATH

    # Update env.sh
tee -a ${PROJDIR_PATH}/${ENVFILE} << EOF
export PATH=\${PROJDIR_PATH}/gcc-arm-${TOOLCHAIN_VER}-x86_64-arm-none-linux-gnueabihf/bin:\$PATH
EOF
    echo "                  ... done"
}

function build_uboot
{
    echo "Building U-Boot ..."
    # Download
    wget -c https://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VER}.tar.bz2
    tar xf u-boot-${UBOOT_VER}.tar.bz2
    mv u-boot-${UBOOT_VER} u-boot

    # Build
    pushd u-boot
    make CROSS_COMPILE=arm-none-linux-gnueabihf- O=build_vexpress vexpress_ca9x4_defconfig
    make CROSS_COMPILE=arm-none-linux-gnueabihf- O=build_vexpress -j4
    popd

tee -a ${PROJDIR_PATH}/${ENVFILE} << EOF
# U-Boot file path
export UBOOT=\${PROJDIR_PATH}/u-boot/build_vexpress/u-boot
EOF

    echo "                ... done"
}

function build_linux
{
    echo "Building linux ..."
    # Download
    wget -c https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${LINUX_VER}.tar.xz
    tar xf linux-${LINUX_VER}.tar.xz
    mv linux-${LINUX_VER} linux

    # Build
    pushd linux
    make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- O=build_vexpress multi_v7_defconfig
    make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- O=build_vexpress -j4
    popd

tee -a ${PROJDIR_PATH}/${ENVFILE} << EOF
# Linux files path
export ZIMAGE=\${PROJDIR_PATH}/linux/build_vexpress/arch/arm/boot/zImage
export DTB=\${PROJDIR_PATH}/linux/build_vexpress/arch/arm/boot/dts/vexpress-v2p-ca9.dtb
EOF

    echo "               ... done"
}

function get_ubuntu
{
    echo "Getting Ubuntu filesystem ..."
    # Download
    wget -c https://rcn-ee.net/rootfs/eewiki/minfs/ubuntu-20.04.3-minimal-armhf-2021-12-20.tar.xz
    tar xf ubuntu-20.04.3-minimal-armhf-2021-12-20.tar.xz

tee -a ${PROJDIR_PATH}/${ENVFILE} << EOF
# Ubuntu rootfs archive
export UBUNTU_TAR=\${PROJDIR_PATH}/ubuntu-20.04.3-minimal-armhf-2021-12-20/armhf-rootfs-ubuntu-focal.tar
EOF
    echo "                          ... done"
}

check_existing $1
build_qemu
get_toolchain
build_uboot
build_linux
get_ubuntu

echo "-------------------------------------------------------------------------"
echo " Done installing QEMU!"
echo "-------------------------------------------------------------------------"
