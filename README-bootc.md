# Copr Image Builder

See the main repository README for more details.


## Testing bootc imagel locally

```
dnf copr enable @osbuild/image-builder
dnf install image-builder
./copr-build-image-bootc.sh local
find -name disk.qcow2
```

Run `virt-manager` and boot the image.


## Publishing the container image

Not the `qcow2` or AMI, but the container image.

```
# Use your standard RedHat login, same for e.g. JIRA
sudo podman login quay.io
sudo podman push localhost/copr-builder quay.io/copr/builder:builder
```

See https://quay.io/repository/copr/builder


## Building on HV

```
mkdir /var/lib/copr-rpmbuild/containers
ln -s /var/lib/copr-rpmbuild/containers /var/lib/containers
cd /var/lib/copr-rpmbuild
git clone https://github.com/fedora-copr/copr-image-builder.git
cd copr-image-builder
./copr-build-image-bootc.sh remote
```

This will produce the final `qcow2` or AMI.
