# Copr Image Builder

See the main repository README for more details.


## Testing bootc image locally

```
IMAGE_TYPE=qcow2 BUILD_OCI=true ./copr-build-image-bootc.sh
```

Run `virt-manager` and boot the image.


## x86_64 qcow2

```
# su - resalloc
$ resalloc ticket --tag hypervisor_x86_64
$ resalloc ticket-wait 751
$ IP=2620:52:3:1:dead:beef:cafe:c1c1
$ ssh root@$IP
# git clone https://github.com/fedora-copr/copr-image-builder.git
# cd copr-image-builder
# ./prepare-worker
# IMAGE_TYPE=qcow2 BUILD_OCI=true ./copr-build-image-bootc.sh
# exit
$ scp -6 root@[$IP]:/root/copr-image-builder/output/qcow2/disk.qcow2 /var/lib/copr/public_html/images/disk.x86_64.qcow2
$ resalloc ticket-close 751

$ scp /var/lib/copr/public_html/images/disk.x86_64.qcow2 copr@vmhost-x86-copr02.rdu-cc.fedoraproject.org:/tmp/disk.qcow2
$ ssh copr@vmhost-x86-copr02.rdu-cc.fedoraproject.org
$ /home/copr/provision/upload-qcow2-images /tmp/disk.qcow2
$ rm /tmp/disk.qcow2
$ exit
```

## x86_64 AMI

```
# su - resalloc
$ resalloc ticket --tag hypervisor_x86_64
$ resalloc ticket-wait 751
$ IP=2620:52:3:1:dead:beef:cafe:c1c1
$ ssh root@$IP
# git clone https://github.com/fedora-copr/copr-image-builder.git
# cd copr-image-builder
# ./prepare-worker
# IMAGE_TYPE=qcow2 BUILD_OCI=true ./copr-build-image-bootc.sh
# IMAGE_TYPE=ami BUILD_OCI=true ./copr-build-image-bootc.sh
# exit
$ scp -6 root@[$IP]:/root/copr-image-builder/output/image/disk.raw /var/lib/copr/public_html/images/disk.x86_64.raw
$ resalloc ticket-close 751
```


## aarch64

```
# su - resalloc
$ resalloc ticket --tag arch_aarch64_native
$ resalloc ticket-wait 751
$ IP=100.26.46.8
$ ssh root@$IP
# git clone https://github.com/fedora-copr/copr-image-builder.git
# cd copr-image-builder
# ./prepare-worker
# IMAGE_TYPE=ami BUILD_OCI=true ./copr-build-image-bootc.sh
# exit
$ scp root@$IP:/root/copr-image-builder/output/image/disk.raw /var/lib/copr/public_html/images/disk.aarch64.raw
$ resalloc ticket-close 751
```


## ppc64le

```
# su - resalloc
$ resalloc ticket --tag hypervisor --tag arch_ppc64le
$ resalloc ticket-wait 751
$ IP=2620:52:3:1:dead:beef:cafe:c1c1
$ ssh root@$IP
# git clone https://github.com/fedora-copr/copr-image-builder.git
# cd copr-image-builder
# ./prepare-worker
# IMAGE_TYPE=qcow2 BUILD_OCI=true ./copr-build-image-bootc.sh
# exit
$ scp -6 root@[$IP]:/root/copr-image-builder/output/qcow2/disk.qcow2 /var/lib/copr/public_html/images/disk.ppc64le.qcow2
$ resalloc ticket-close 751

$ scp /var/lib/copr/public_html/images/disk.ppc64le.qcow2 copr@vmhost-p08-copr01.rdu-cc.fedoraproject.org:/tmp/disk.qcow2
$ ssh copr@vmhost-p08-copr01.rdu-cc.fedoraproject.org
$ /home/copr/provision/upload-qcow2-images /tmp/disk.qcow2
$ rm /tmp/disk.qcow2
$ exit
```


## s390x

```
# su - resalloc
$ resalloc ticket --tag arch_s390x_native
$ resalloc ticket-wait 751
$ IP=13.116.88.91
$ ssh root@$IP
# git clone https://github.com/fedora-copr/copr-image-builder.git
# cd copr-image-builder
# ./prepare-worker
# IMAGE_TYPE=qcow2 BUILD_OCI=true ./copr-build-image-bootc.sh
# exit
$ scp root@$IP:/root/copr-image-builder/output/qcow2/disk.qcow2 /var/lib/copr/public_html/images/disk.s390x.qcow2
$ resalloc ticket-close 751

$ exit
# qcow_image=/var/lib/copr/public_html/images/disk.s390x.qcow2
# podman_image=quay.io/praiskup/ibmcloud-cli
# export IBMCLOUD_API_KEY=....  # find in Bitwarden
# podman run -e IBMCLOUD_API_KEY --rm -ti --network=slirp4netns -v $qcow_image:/image.qcow2:z $podman_image upload-image
```



## Obsolete

The rest of this document is probably outdated and likely to be deleted.

### HV x86_64

```bash
# Laptop
IMAGE_TYPE=qcow2 BUILD_OCI=true ARCH=x86_64 ./copr-build-image-bootc.sh
scp output/qcow2/disk.qcow2 copr@vmhost-x86-copr02.rdu-cc.fedoraproject.org:/tmp/
ssh copr@vmhost-x86-copr02.rdu-cc.fedoraproject.org

# HV
/home/copr/provision/upload-qcow2-images /tmp/disk.qcow2
rm /tmp/disk.qcow2
```

Edit `inventory/group_vars/copr_dev_aws` in the Fedora Infra Ansible repo and
set `copr_builder_images.hypervisor.x86_64`, commit, push, run playbook, remove
unused builders, etc.


### HV and OSUOSL ppc64le

```bash
# Laptop
IMAGE_TYPE=qcow2 BUILD_OCI=true ARCH=ppc64le ./copr-build-image-bootc.sh
scp output/qcow2/disk.qcow2 copr@vmhost-p08-copr01.rdu-cc.fedoraproject.org:/tmp
ssh copr@vmhost-p08-copr01.rdu-cc.fedoraproject.org

# HV
/home/copr/provision/upload-qcow2-images /tmp/disk.qcow2
rm /tmp/disk.qcow2
```


### AWS x86_64

Still WIP:

```
IMAGE_TYPE=ami BUILD_OCI=true ARCH=x86_64 ./copr-build-image-bootc.sh
image-builder upload \
    ./output/image/disk.raw \
    --to aws \
    --aws-ami-name copr-builder-image-x86_64-bootc \
    --aws-region us-east-1 \
    --aws-bucket copr-images
```

The `fedora-copr` bucket is in `us-east-2` but builders are in `us-east-1`, so
we will have to abuse the `copr-pulp-prod` bucket or create a new one. Anyway,
the command fails with the following error for both buckets:

```
error: UnauthorizedOperation: You are not authorized to perform this operation. User: arn:aws:iam::125523088429:user/copr is not authorized to perform: ec2:ImportSnapshot on resource: arn:aws:ec2:us-east-2:125523088429:import-snapshot-task/* because no identity-based policy allows the ec2:ImportSnapshot action. Encoded authorization failure message: zaaW4-EiGWPG2j8YbMS_QJlZX8hDVf5mrSigNRGLF31XaEcDxzn8tiEjrB7gHSKgin33KVKzk0LzUjhCNuQ197m-rEjWxKZKMjAFYmROzyc19OIamAS2OmX940dvszyHDZTc3PFx_-oTkTEkPYk-FT5teTcq3LKc29u8bm3DvfIoFcLNsRztn65bVKguQ6e7nv7MJEPMqvigs6I7k56brKfZqUMYWQ--vbq487pg8p_QmFoqSkMfUt_Nwi83LjLb1ehtLuHlrcyzzfxcEKVjQS3GJ8Oks4Ctt_GOmI9L0Ttuyi6Ypo3_-GGPZpLDSMzI5XlAT0a-joObN49mOUztmW4pFOGBTq0OPD10AjzFhSe_9dIadfukA3YoKzeOsrSQ4xdq70_aO6rovzGWY5izZu0VHNOkFp_25cG3NaJ8mgz3LbSp1RMGx2U9c08DrPPgiTUxBnvubT4qD7Lw_2_hRIkU2O4e9JFqy8Q6zH71jug8XmrSLMMq1adlcvdE2Vk3Zm35dM0CVitN
        status code: 403, request id: e1668bdf-7195-4f38-8d3a-09edde9e97c7
```


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
rm -rf /var/lib/containers
mkdir /var/lib/copr-rpmbuild/containers
ln -s /var/lib/copr-rpmbuild/containers /var/lib/containers
cd /var/lib/copr-rpmbuild
git clone https://github.com/fedora-copr/copr-image-builder.git
cd copr-image-builder
IMAGE_TYPE=qcow2 BUILD_OCI=true ./copr-build-image-bootc.sh
```

This will produce the final `qcow2` or AMI.
