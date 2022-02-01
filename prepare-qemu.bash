#!/bin/bash

# Global definitions
ENVFILE=env.sh
SD_FILE=sd.img
BOOT_MNT=/run/mount/boot
ROOT_MNT=/run/mount/rootfs

if [ `id -u` -eq 0 ]; then
    echo "Must run as regular user"
    exit
fi

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
    sudo mkdir -p $BOOT_MNT
    sudo mount /dev/mapper/${loop_nr}p1 $BOOT_MNT
    sudo cp $ZIMAGE $BOOT_MNT
    sudo cp $DTB $BOOT_MNT
    sudo umount $BOOT_MNT

    # Copy rootfs files
    sudo mkdir -p $ROOT_MNT
    sudo mount /dev/mapper/${loop_nr}p2 $ROOT_MNT
    sudo tar xfvp $UBUNTU_TAR -C $ROOT_MNT

    # Copy kernel modules
    pushd ${PROJDIR_PATH}/linux/build_vexpress
    sudo make ARCH=arm INSTALL_MOD_PATH=$ROOT_MNT modules_install
    sync
    popd

    sudo umount $ROOT_MNT
    sudo kpartx -d $PROJDIR_PATH/$SD_FILE

    echo "                     ... done"
}

source $ENVFILE
prepare_sd_image

echo "-------------------------------------------------------------------------"
echo " Done preparing QEMU!"
echo "-------------------------------------------------------------------------"
