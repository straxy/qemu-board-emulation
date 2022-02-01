#!/bin/bash

ENVFILE=env.sh
ROOT_MNT=/run/mount/rootfs

if [ `id -u` -eq 0 ]; then
    echo "Must run as regular user"
    exit
fi

# error handling
set -e

function umount_sd_image
{
   # umount rootfs partition
   sudo umount ${ROOT_MNT}

   # remove SD card
   sudo kpartx -d ${SD_IMG}
}

# source environment variables
source ${ENVFILE}
umount_sd_image

echo "-------------------------------------------------------------------------"
echo " Finished umounting SD Card ${SD_IMG}!"
echo " You can use it now!"
echo "-------------------------------------------------------------------------"
