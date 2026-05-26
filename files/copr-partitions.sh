#!/usr/bin/bash

# This script runs once at boot (via copr-partitions.service) and prepares
# the builder's storage:
#   1) A 16G ext4 partition for build results (/var/lib/copr-rpmbuild)
#   2) The rest of the disk as swap (used by mock as a cache backing store
#      so builds don't run out of space on tmpfs)
#
# Handles all environments. The partitioning logic is:
#   - Try to find a large (>150G) unmounted block device and partition it
#   - If none found, fall back to file-based storage on /var

set -x
set -e

# these are to be decided, it depends where we spawn the machine
results_storage=
swap_storage=

# how much space to reserve for build results config
results_size=16G
results_dir=/var/lib/copr-rpmbuild


# Repartition given device path into results+swap storage.
# $1 is path to the device
# $2 is part prefix, e.g., "" for /dev/vda2 but "p" for /dev/nvme1n1p2
# outputs: $results_storage and $swap_storage
repartition_device()
{
    device=$1
    part_suffix=$2
    echo "\
n
p


+$results_size
n
p
2


w
" | fdisk "$device"

    # Wait till the partition appears
    partprobe || :
    partition=${device}${part_suffix}2
    while ! test -e "$partition"; do
        sleep 0.1
    done

    results_storage=$device${part_suffix}1
    swap_storage=$device${part_suffix}2
}


try_indefinitely()
{
    while :; do
        "$@" && break
        sleep 2
    done
}

# Prepare large files if we don't have device to work with.
# $1 location where to create files
# $2 swap size, e.g. 100G
# outputs: $results_storage and $swap_storage
mountpoints_as_files()
{
    location=$1
    swap_size=$2
    results_storage=$location/ext4-results
    try_indefinitely fallocate -l "$results_size" "$results_storage"

    swap_storage=$location/swap
    try_indefinitely fallocate -l "$swap_size" "$swap_storage"
}



# make sure /tmp is tmpfs
systemctl unmask tmp.mount
systemctl start tmp.mount


# Try to find a large unmounted block device.  Covers:
#   /dev/vd[a-z]          -- virtio disks (hypervisors, IBM Cloud VPC)
#   /dev/sd[a-z]          -- SCSI disks (HV with bus=scsi, PowerVS)
#   /dev/nvme[0-9]n[0-9]  -- NVMe devices (AWS)
#
# Skips devices that are already mounted (root disk) or too small (<150G,
# e.g. OpenStack ephemeral disks).  Returns 0 on success, 1 if nothing found.
generic_mount()
{
    # Single-digit suffixes are intentional -- Copr builders never have 10+ disks.
    for vol in /dev/vd[a-z] /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
        test -b "$vol" || continue
        mount | grep -q "$vol" && continue
        size=$(blockdev --getsize64 "$vol") || continue
        test "$size" -le 150000000000 && continue

        case $vol in
            /dev/nvme*)
                repartition_device "$vol" "p"
                ;;
            *)
                repartition_device "$vol" ""
                ;;
        esac
        return 0
    done
    return 1
}


if generic_mount; then
    :
else
    # No suitable block device.  Fall back to file-based storage on /var.
    # This happens on OSUOSL Power builders which only have a root disk.
    # Calculate swap size dynamically from available /var space.
    avail_gb=$(df -BG --output=avail /var | tail -1 | tr -dc '0-9')
    avail_gb=${avail_gb:-0}
    # Reserve 16G for results + 10G buffer for the OS
    swap_gb=$((avail_gb - 26))

    if [ "$swap_gb" -le 30 ]; then
        echo >&2 "No ephemeral disk and insufficient /var space (${avail_gb}G available)"
        exit 1
    fi
    mountpoints_as_files /var ${swap_gb}G
fi


# format and mount the results partition
mkfs.ext4 "$results_storage"
mount "$results_storage" "$results_dir"

# Restore the overmounted package files.
mkdir "$results_dir/results"
mkdir "$results_dir/workspace"
rpm --setperms copr-rpmbuild || :
rpm --setugids copr-rpmbuild || :

# Mount swap.
mkswap "$swap_storage"
swapon "$swap_storage"
