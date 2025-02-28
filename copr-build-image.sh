#!/bin/bash

if [ -z "${IMAGE_TYPE}" ]; then
    echo "Set IMAGE_TYPE to qcow2 or ami"
    exit 1
fi

# dnf -y copr enable @osbuild/image-builder
# At least now, we have to fully update the system because otherwise
# image-buidler fails with some cryptic DNF error
dnf -y update

dnf -y copr enable @osbuild/image-builder
dnf -y install image-builder
curl https://raw.githubusercontent.com/fedora-copr/copr-image-builder/refs/heads/main/config.toml > config.toml

# We don't have much disk space on the root partition, let's abuse
# copr-rpmbuild directory
workdir="/var/lib/copr-rpmbuild/"

image-builder build "$IMAGE_TYPE" \
    --blueprint ./config.toml \
    --output-dir "$workdir" \
    --cache "$workdir" \
    --data-dir "$workdir"

echo "Generated image:"
find "$workdir" -name disk.qcow2
find "$workdir" -name image.raw
