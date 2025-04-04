#!/bin/bash -eu

if [[ $# != 1 ]] || [[ $1 != "--yes" ]]; then
    echo "$(basename $0): Format and mount EC2 ephemeral storage."
    echo "Usage: $(basename $0) --yes"
    exit 1
fi

shopt -s nullglob
devices=(/dev/xvd[b-m] /dev/disk/by-id/nvme-Amazon_EC2_NVMe_Instance_Storage_AWS?????????????????)
if [[ ${#devices[@]} == 0 ]]; then
    echo "No ephemeral devices found"
    exit
fi

if [[ -e /dev/md0 ]]; then
    echo "/dev/md0 already exists"
else
    yes|mdadm --create --force --verbose /dev/md0 --level=0 --raid-devices=${#devices[@]} ${devices[@]}
    blockdev --setra 16384 /dev/md0
    mkfs.xfs -L aegveph -f /dev/md0
fi

if grep -q aegveph /etc/fstab; then
    echo "Ephemeral device already in fstab"
else
    echo -e "LABEL=aegveph\t/mnt\tauto\tdefaults\t0\t0" >> /etc/fstab
fi

mount -a