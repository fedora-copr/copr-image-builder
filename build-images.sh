#! /bin/bash -ex

# This file is a database of Fedora's Copr ARCH => IMAGE matrix.

cd /tmp || exit 1

test -n "$ARCH"
test -n "$IMAGE"

case $ARCH in
x86_64)
    # We maintain both hypervisors (raw) and AWS (ami) images.  Please build
    # ami first, otherwise the disk.raw gets overwritten by the ami job.
    IMAGE_TYPE=ami BUILD_OCI=false bash ./copr-build-image-bootc.sh
    IMAGE_TYPE=raw BUILD_OCI=false bash ./copr-build-image-bootc.sh
    ;;
aarch64)
    # We have just workers in AWS (ami).
    IMAGE_TYPE=ami BUILD_OCI=false bash ./copr-build-image-bootc.sh
    ;;
ppc64le)
    # We have workers in OSUOSL and on hypervisors (both prefer raw)
    IMAGE_TYPE=raw BUILD_OCI=false bash ./copr-build-image-bootc.sh
    ;;
s390x)
    # s390x is only in IBM Cloud
    IMAGE_TYPE=qcow2 BUILD_OCI=false bash ./copr-build-image-bootc.sh
    ;;
esac
