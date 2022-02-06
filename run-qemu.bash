#!/bin/bash

ENVFILE=env.sh
ROOT_MNT=/run/mount/rootfs

if [ `id -u` -eq 0 ]; then
   echo "Must run as regular user"
   exit
fi

function run_qemu
{
   echo "Starting QEMU"
   qemu-system-arm \
      -machine vexpress-a9 \
      -m 1G \
      -kernel ${UBOOT} \
      -drive file=sd.img,format=raw,if=sd \
      -serial mon:stdio \
      -net nic \
      -net tap,ifname=qemu-tap0,script=no,downscript=no
}

function check_network
{
   if [ ! -L /sys/class/net/qemu-tap0 ]; then
      echo "QEMU network is not initialized, please initialize!"
      echo "Exiting ..."
      exit
   fi
}

function check_mount
{
   if mount | grep ${ROOT_MNT} > /dev/null; then
      echo "SD card is still mounted, please umount first!"
      echo "Exiting ..."
      exit
   fi
}

source ${ENVFILE}
check_mount
check_network
run_qemu
