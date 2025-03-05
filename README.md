# Copr Image Builder

The current way of building Copr builder images is described here:
https://docs.pagure.org/copr.copr/how_to_upgrade_builders.html

This project aims to use Image Builder instead.


## End Goals

- Building all images in hosted Image Builder instance
- Support for all architectures: x86_64, aarch64, ppc64le, and s390x
- CI/CD through Packit or GitHub actions
    - Automatic rebuilds when a relevant code is changed
    - Automatic weekly rebuilds
- At maximum 5 minutes of work to upgrade builder images in all clouds and for
  all architectures


## Where we are at

- We have a blueprint allowing us to build an image locally
    - All image-preparation tasks from our Ansible playbook were either migrated
      or marked as TODO within the blueprint
- The "local" build can be run in a VM on all architectures we need
- Building on a hosted Image Builder instance is not easy because:
    - There is no CLI tool, only API. To be fair
      [there is a proof-of-concept](https://github.com/supakeen/image-builder-api-client)
      but allegedly it doesn't work well.
    - API doesn't support uploading an existing blueprint file, because it is
      not compatible with the API schema. It is being worked on -
      https://issues.redhat.com/browse/HMS-4884



## Testing image locally

```
dnf copr enable @osbuild/image-builder
dnf install image-builder
sudo image-builder build qcow2 --blueprint ./config.toml
find -name disk.qcow2
```

Run `virt-manager` and boot the image.


## x86_64

```
# su - resalloc
$ resalloc ticket --tag hypervisor_x86_64
$ resalloc ticket-wait 751
$ ssh root@2620:52:3:1:dead:beef:cafe:c1c1
# curl https://raw.githubusercontent.com/fedora-copr/copr-image-builder/refs/heads/main/copr-build-image.sh > copr-build-image.sh
# chmod +x copr-build-image.sh
# IMAGE_TYPE=qcow2 ./copr-build-image.sh
# IMAGE_TYPE=ami ./copr-build-image.sh
# exit
$ resalloc ticket-close 751
```


## aarch64

```
# su - resalloc
$ resalloc ticket --tag arch_aarch64_native
$ resalloc ticket-wait 751
$ ssh root@2620:52:3:1:dead:beef:cafe:c1c1
# curl https://raw.githubusercontent.com/fedora-copr/copr-image-builder/refs/heads/main/copr-build-image.sh > copr-build-image.sh
# chmod +x copr-build-image.sh
# IMAGE_TYPE=ami ./copr-build-image.sh
# exit
$ resalloc ticket-close 751
```


## ppc64le

Currently fails because of
https://github.com/osbuild/image-builder-cli/issues/141


```
# su - resalloc
$ resalloc ticket --tag hypervisor_ppc64le
$ resalloc ticket-wait 751
$ ssh root@2620:52:3:1:dead:beef:cafe:c1c1
# curl https://raw.githubusercontent.com/fedora-copr/copr-image-builder/refs/heads/main/copr-build-image.sh > copr-build-image.sh
# chmod +x copr-build-image.sh
# IMAGE_TYPE=qcow2 ./copr-build-image.sh
# exit
$ resalloc ticket-close 751
```


## s390x

```
# su - resalloc
$ resalloc ticket --tag arch_s390x_native
$ resalloc ticket-wait 751
$ ssh root@2620:52:3:1:dead:beef:cafe:c1c1
# curl https://raw.githubusercontent.com/fedora-copr/copr-image-builder/refs/heads/main/copr-build-image.sh > copr-build-image.sh
# chmod +x copr-build-image.sh
# IMAGE_TYPE=qcow2 ./copr-build-image.sh
# exit
$ resalloc ticket-close 751
```
