#!/bin/bash

ENVFILE=env.sh
ROOT_MNT=/run/mount/rootfs

if [ `id -u` -eq 0 ]; then
   echo "Must run as regular user"
   exit
fi

# error handling
set -e

function mount_sd_image
{
   # insert SD card
   loop_nr=$(sudo kpartx -av ${SD_IMG} | grep -Po 'loop.+?(?=p)' | tail -1)
   sleep 1

   # mount rootfs partition
   sudo mkdir -p ${ROOT_MNT}
   sudo mount -t ext4 /dev/mapper/${loop_nr}p2 ${ROOT_MNT}
}

# source environment variables
source ${ENVFILE}
mount_sd_image

echo "-------------------------------------------------------------------------"
echo " Finished mounting SD image to ${ROOT_MNT}"
echo " NOTE: Remember to run umount script before using the image!"
echo "-------------------------------------------------------------------------"
