#!/bin/bash

mkdir -p output
sudo podman build --network host -t copr-builder . || exit 1
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
     localhost/copr-builder
