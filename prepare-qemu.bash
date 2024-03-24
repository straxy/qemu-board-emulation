#!/bin/bash

# Global definitions
ENVFILE=env.sh
SD_FILE=sd.img
ROOTFS_TMP=/run/tmp/rootfs
BOOT_MNT=/run/mount/boot
ROOT_MNT=/run/mount/rootfs

if [ `id -u` -eq 0 ]; then
    echo "Must run as regular user"
    exit
fi

function make_rootfs
{
    sudo apt install -y qemu-user-static binfmt-support
    sudo mkdir -p $ROOTFS_TMP
    sudo tar xzvf $UBUNTU_BASE -C $ROOTFS_TMP

    # Prepare chroot
    sudo tee -a ${ROOTFS_TMP}/etc/resolv.conf << "EOF"
nameserver 8.8.8.8
EOF
    sudo mount --bind /dev ${ROOTFS_TMP}/dev
    sudo mount --bind /dev/pts ${ROOTFS_TMP}/dev/pts
    sudo mount --bind /proc ${ROOTFS_TMP}/proc

    # Prepare commands in chroot
    sudo tee -a ${ROOTFS_TMP}/startup.sh << "EOF"
# Prepare image
apt update
apt install -y --no-install-recommends \
    systemd \
    dbus \
    init \
    kmod \
    udev \
    iproute2 \
    iputils-ping \
    vim \
    sudo
# Add user ubuntu with password temppwd
useradd -G sudo -m -s /bin/bash ubuntu
echo ubuntu:temppwd | chpasswd
# Setup hostname and hosts file
echo mistra > /etc/hostname
echo 127.0.0.1	localhost > /etc/hosts
echo 127.0.1.1	mistra >> /etc/hosts
# Cleanup
apt clean
rm /var/lib/apt/lists/ports.ubuntu.com*
exit
EOF
    sudo chmod +x ${ROOTFS_TMP}/startup.sh
    # Enter chroot
    sudo chroot ${ROOTFS_TMP} /bin/bash -c /startup.sh
    sudo rm ${ROOTFS_TMP}/startup.sh
    # Setup network
    sudo tee -a ${ROOTFS_TMP}/etc/systemd/network/20-wired.network << "EOF"
[Match]
Name=eth0

[Network]
Address=192.168.123.101/24
Gateway=192.168.123.1
DNS=8.8.8.8
EOF

    # Cleanup
    sudo umount ${ROOTFS_TMP}/proc
    sudo umount ${ROOTFS_TMP}/dev/pts
    sudo umount ${ROOTFS_TMP}/dev

    # Archive
    sudo tar cJvfp ubuntu-minimal-22.04.tar.xz -C ${ROOTFS_TMP} .
}

function prepare_sd_image
{
    echo "Preparing SD card image ..."

    cd $PROJDIR_PATH
    qemu-img create $SD_FILE 4G

tee -a ${PROJDIR_PATH}/$ENVFILE << EOF
# SD card image
export SD_IMG=\${PROJDIR_PATH}/${SD_FILE}
EOF

    # Partition
    sfdisk ./${SD_FILE} << EOF
,64M,c,*
,,L,
EOF

    # Format
    loop_nr=$(sudo kpartx -av $SD_FILE | grep -Po 'loop.+?(?=p)' | tail -1)
    sleep 1
    sudo mkfs.vfat -F 32 -n "BOOT" /dev/mapper/${loop_nr}p1
    sudo mkfs.ext4 -L rootfs /dev/mapper/${loop_nr}p2

    # Copy boot files
    tee -a boot.cmd << "EOF"
fatload mmc 0:1 42000000 zImage
fatload mmc 0:1 43000000 sun4i-a10-cubieboard.dtb
setenv bootargs "console=ttyS0 root=/dev/mmcblk0p2 rw"
bootz 0x42000000 - 0x43000000
EOF
    mkimage -C none -A arm -T script -d boot.cmd boot.scr
    sudo mkdir -p $BOOT_MNT
    sudo mount /dev/mapper/${loop_nr}p1 $BOOT_MNT
    sudo cp $ZIMAGE $BOOT_MNT
    sudo cp $DTB $BOOT_MNT
    sudo cp boot.scr $BOOT_MNT
    sudo umount $BOOT_MNT

    make_rootfs

    # Copy rootfs files
    sudo mkdir -p $ROOT_MNT
    sudo mount /dev/mapper/${loop_nr}p2 $ROOT_MNT
    sudo tar xfvp ubuntu-minimal-22.04.tar.xz -C $ROOT_MNT

    # Copy kernel modules
    pushd ${PROJDIR_PATH}/linux/build_cubieboard
    sudo make ARCH=arm INSTALL_MOD_PATH=$ROOT_MNT modules_install
    sync
    popd

    sudo umount $ROOT_MNT
    sudo kpartx -d $PROJDIR_PATH/$SD_FILE

    # Copy U-Boot
    dd if=$UBOOT_SPL of=$SD_IMG bs=1024 seek=8 conv=notrunc

    echo "                     ... done"
}

source $ENVFILE
prepare_sd_image

echo "-------------------------------------------------------------------------"
echo " Done preparing QEMU!"
echo "-------------------------------------------------------------------------"
