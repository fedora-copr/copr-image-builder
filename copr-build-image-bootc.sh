#!/bin/bash

if [ -z "${IMAGE_TYPE}" ]; then
    echo "Set IMAGE_TYPE to qcow2 or ami"
    exit 1
fi

if [ -z "${BUILD_OCI}" ]; then
    echo "Set BUILD_OCI to true to build locally or false to pull from registry"
    exit 1
fi


if [ "$BUILD_OCI" == true ]; then
    IMAGE="localhost/copr-builder"
    sudo podman build --network host -t $IMAGE . || exit 1
else
    IMAGE="quay.io/copr/builder"
    sudo podman pull $IMAGE || exit 1
fi


mkdir -p output
sudo podman pull quay.io/centos-bootc/centos-bootc:stream9 || exit 1
sudo podman run \
     --rm \
     -it \
     --privileged \
     --pull=newer \
     --security-opt label=type:unconfined_t \
     -v ./output:/output \
     -v /var/lib/containers/storage:/var/lib/containers/storage \
     quay.io/centos-bootc/bootc-image-builder:latest \
     --type "$IMAGE_TYPE" \
     --rootfs xfs \
     --use-librepo=True \
     $IMAGE \
     || exit 1

echo "Generated image:"
find output -name disk.qcow2
find output -name disk.raw
