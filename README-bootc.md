# Copr Image Builder

See the main repository README for more details.


## Testing bootc image locally

```
IMAGE_TYPE=qcow2 BUILD_OCI=true ARCH=x86_64 ./copr-build-image-bootc.sh
```

Run `virt-manager` and boot the image.


## Deploying to STG

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
