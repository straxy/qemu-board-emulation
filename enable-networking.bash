#!/bin/bash

# error handling
set -e

if [ `id -u` -eq 0 ]; then
   echo "Must run as regular user"
   exit
fi

USERNAME=$(whoami)

if [ $# -eq 1 ]; then
    INTERFACE=$1
else
    echo "Please select network interface that will be used for external connection:"
    i=0
    IFACES=$(ls /sys/class/net)
    IFACES_ARRAY=()
    for iface in $(ls /sys/class/net); do
        i=$(($i+1))
        echo $i: $iface
        IFACES_ARRAY+=($iface)
    done

    read selected

    case "$selected" in
        ("" | *[!0-9]*)
            echo 'Error (not a number between 1 and '$i')'
            exit 1
    esac

    if [ $selected -gt $i ]; then
        echo "Wrong selection, exiting..."
        exit 1
    fi

    INTERFACE=${IFACES_ARRAY[$(($selected-1))]}
fi

function enable_network
{
sudo -s << EOF
ip tuntap add dev qemu-tap0 mode tap user $USERNAME
ifconfig qemu-tap0 192.168.123.1
route add -net 192.168.123.0 netmask 255.255.255.0 dev qemu-tap0
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
iptables -I FORWARD 1 -i qemu-tap0 -j ACCEPT
iptables -I FORWARD 1 -o qemu-tap0 -m state --state RELATED,ESTABLISHED -j ACCEPT
EOF
}

# check if network exists; remove if present
function check_network
{
   if [ ! -L /sys/class/net/qemu-tap0 ]; then
      echo "Network missing, enable it"
      enable_network
   fi
}

check_network

echo "-------------------------------------------------------------------------"
echo " QEMU network enabled!"
echo "-------------------------------------------------------------------------"
