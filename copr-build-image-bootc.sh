#!/bin/bash

: "${CONTEXT:=.}"
: "${BUILD_BOOTC:=true}"
: "${IMAGE:=localhost/copr-builder}"


if [ -z "${IMAGE_TYPE}" ]; then
    echo "Set IMAGE_TYPE to qcow2, raw or ami (see https://github.com/osbuild/bootc-image-builder?tab=readme-ov-file#-image-types)"
    exit 1
fi

if [ -z "${BUILD_OCI}" ]; then
    echo "Set BUILD_OCI to true to build locally or false to pull from registry"
    exit 1
fi

if [ "$BUILD_OCI" == true ]; then
    # The LINUX_IMMUTABLE is needed for doing chattr when building the image.
    # We use it for Internal Copr builders
    sudo podman build \
        --cap-add LINUX_IMMUTABLE \
        --network host \
        -t $IMAGE \
        $CONTEXT \
        || exit 1
else
    sudo podman pull $IMAGE || exit 1
fi


if [ "$BUILD_BOOTC" == true ]; then
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
         $IMAGE \
         || exit 1

    echo "Generated image:"

    case $IMAGE_TYPE in
    qcow2)
        find output -name disk.qcow2
        ;;
    ami)
        image=$(find output -name disk.raw)
        mv "$image" "${image//.raw/.ami}"
        find output -name disk.ami
        ;;
    raw)
        find output -name disk.raw
        ;;
    esac
fi
