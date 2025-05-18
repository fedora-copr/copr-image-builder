#!/bin/bash

if [ -z "${IMAGE_TYPE}" ]; then
    echo "Set IMAGE_TYPE to qcow2 or ami"
    exit 1
fi

if [ -z "${BUILD_OCI}" ]; then
    echo "Set BUILD_OCI to true to build locally or false to pull from registry"
    exit 1
fi

if [ -z "${ARCH}" ]; then
    echo "Set ARCH to x86_64, aarch64, ppc64le, or s390x"
    exit 1
fi


if [ "$BUILD_OCI" == true ]; then
    IMAGE="localhost/copr-builder"
    sudo podman build --platform="linux/$ARCH" --network host -t $IMAGE . || exit 1
else
    IMAGE="quay.io/copr/builder"
    sudo podman pull --platform="linux/$ARCH" $IMAGE || exit 1
fi


mkdir -p output
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
     --target-arch "$ARCH" \
     $IMAGE \
     || exit 1

echo "Generated image:"
find output -name disk.qcow2
find output -name disk.raw
