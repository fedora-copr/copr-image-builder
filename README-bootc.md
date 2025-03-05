# Copr Image Builder

See the main repository README for more details.


## Testing bootc imagel locally

```
dnf copr enable @osbuild/image-builder
dnf install image-builder
./copr-build-image-bootc.sh
find -name disk.qcow2
```

Run `virt-manager` and boot the image.


## Publishing the container image

Not the `qcow2` or AMI, but the container image.

```
sudo podman login quay.io
sudo podman push localhost/copr-builder:latest quay.io/copr/builder
```
