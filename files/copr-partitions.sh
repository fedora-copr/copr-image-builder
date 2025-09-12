#!/usr/bin/bash

set -x
set -e

# these are to be decided, it depends where we spawn the machine
results_storage=
swap_storage=

# global config
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


# Prepare large files if we don't have device to work with.
# $1 location where to create files
# $2 swap size, e.g. 100G
# outputs: $results_storage and $swap_storage
mountpoins_as_files()
{
    location=$1
    swap_size=$2
    results_storage=$location/ext4-results
    fallocate -l "$results_size" "$results_storage"

    swap_storage=$location/swap
    fallocate -l "$swap_size" "$swap_storage"
}



# make sure /tmp is tmpfs
systemctl unmask tmp.mount
systemctl start tmp.mount


generic_mount()
{
    # Find a "very large" volume — that one will be used (IBM Cloud assigns the
    # swap volume name randomly, hypervisors have /var/vdb).
    for vol in /dev/vdb /dev/vdc /dev/vdd /dev/vda; do
       mount | grep $vol && continue
       size=$(blockdev --getsize64 "$vol")
       test "$size" -le 150000000000 && continue
       repartition_device "$vol" ""
       break
    done
}


if test -f /config/resalloc-vars.sh; then
    # VMs on our hypervisors have this file created, providing some basic info
    # about the "pool ID" (== particular hypervisor).  On hypervisors, we
    # prepare /dev/vdN device, detect it and partition in.
    generic_mount
elif grep -E 'POWER9|POWER10' /proc/cpuinfo; then
    # OpenStack Power9/Power10 setup. We have only one large volume there.
    # Partitioning using cloud-init isn't trival, especially considering we
    # share the Power8 and Power9 builder images so we create a swap file
    # on /var filesystem (btrfs).  Reminder! with bootc, / filesystem is just a
    # small composefs stored in hosts' /run, see
    # https://github.com/fedora-copr/copr-image-builder/issues/11.
    if grep POWER10 /proc/cpuinfo; then
        # WARNING/TODO: this is for powerful builders only, but it's hardcoded
        # and will stop working once we switch to p10. The setup should be done
        # generically, as stated in the comment above, so the large swap file
        # is created automatically upon the on_demand_powerful tag configuration.
        mountpoins_as_files /var 294G
    else
        mountpoins_as_files /var 148G
    fi
elif test -e /dev/xvda1 && test -e /dev/nvme0n1; then
    # AWS aarch64 machine.  We use separate volume allocation as the default
    # root disk in our instance type is too small.
    repartition_device /dev/nvme0n1 "p"
elif test -e /dev/nvme1n1; then
    # AWS x86_64 machine.  There's >= 400G space on the default volume in our
    # instance type.
    repartition_device /dev/nvme1n1 "p"
else
    # This should be a machine in IBM Cloud, /dev/vdX pattern.
    generic_mount
fi

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
