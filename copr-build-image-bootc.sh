#!/bin/bash

# Expected values are "local" and "remote"
WHERE=${1:-local}

if [ "$WHERE" == "local" ]; then
    IMAGE="localhost/copr-builder"
    sudo podman build --network host -t $IMAGE . || exit 1
else
    IMAGE="quay.io/copr/builder"
    sudo podman pull $IMAGE
fi


mkdir -p output
sudo podman pull quay.io/centos-bootc/centos-bootc:stream9 || exit 1
sudo podman run \
     --rm \
     -it \
     --privileged \
     --pull=newer \
     --security-opt label=type:unconfined_t \
     -v ./config.toml:/config.toml:ro \
     -v ./output:/output \
     -v /var/lib/containers/storage:/var/lib/containers/storage \
     quay.io/centos-bootc/bootc-image-builder:latest \
     --type qcow2 \
     --rootfs xfs \
     --use-librepo=True \
     $IMAGE

echo "Generated image:"
find "$workdir" -name disk.qcow2
find "$workdir" -name image.raw
