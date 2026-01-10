# This Containerfile is based on an ansible playbook for provisioning Copr builders
# https://pagure.io/fedora-infra/ansible/blob/main/f/roles/copr/backend/files/provision/provision_builder_tasks.yml
FROM quay.io/fedora/fedora-bootc:42@sha256:50277bf41f2fe8f42854572dacbadc4125c1db3e607585679eeb695a8e2043d5

# Disable zram SWAP on builders, it is too small, issue 2077
RUN dnf -y remove zram-generator-defaults && dnf -y clean all

# TODO work-around for wrongly generated ami
# I guess we can remove this?

# TODO disable updates-testing
# TODO update the system
# TODO disable updates-testing, could be restored after update
# Can we assume the image is always fully updated and skip all of these?

# TODO clean dnf cache before checking for updated packages
# Can we skip this?

# Set lower metadata expire time to enforce download
RUN echo "metadata_expire=1h" >> /etc/dnf/dnf.conf

# put infra repos into yum.repos.d
RUN cat > /etc/yum.repos.d/infra-tags.repo <<'EOF'
[infrastructure-tags]
name=Fedora Infrastructure tag $releasever - $basearch
baseurl=https://kojipkgs.fedoraproject.org/repos-dist/f$releasever-infra/latest/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://infrastructure.fedoraproject.org/repo/infra/RPM-GPG-KEY-INFRA-TAGS
EOF

# Fallback to the legacy crypto policies
# https://fedoraproject.org/wiki/Changes/StrongCryptoSettings
RUN update-crypto-policies --set DEFAULT:SHA1

# Document why we need those packages!
# - parted - /sbin/partprobe needed by copr-partitions.service
# - qemu-guest-agent - make sure libvirt knows IP addresses
RUN dnf -y install \
    cloud-init \
    subscription-manager \
    copr-builder \
    qemu-guest-agent \
    parted \
    python3-copr-common \
    rpmlint \
    tito \
    fedora-review \
    bc \
    pyp2spec \
    python3-libdnf5 \
    && dnf -y clean all

# TODO Collect facts about builder hardware
# We can probably skip this, it looks like starting_builder task

# Run /bin/copr-update-builder from copr-builder package
RUN /usr/bin/copr-update-builder

# mockbuild user
RUN useradd mockbuilder -G mock

# mockbuilder .ssh
RUN mkdir /home/mockbuilder/.ssh \
    && chmod 0700 /home/mockbuilder/.ssh \
    && chown mockbuilder:mockbuilder /home/mockbuilder/.ssh

# mockbuilder authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCeTO0ddXuhDZYM9HyM0a47aeV2yIVWhTpddrQ7/RAIs99XyrsicQLABzmdMBfiZnP0FnHBF/e+2xEkT8hHJpX6bX81jjvs2bb8KP18Nh8vaXI3QospWrRygpu1tjzqZT0Llh4ZVFscum8TrMw4VWXclzdDw6x7csCBjSttqq8F3iTJtQ9XM9/5tCAAOzGBKJrsGKV1CNIrfUo5CSzY+IUVIr8XJ93IB2ZQVASK34T/49egmrWlNB32fqAbDMC+XNmobgn6gO33Yq5Ly7Dk4kqTUx2TEaqDkZfhsVu0YcwV81bmqsltRvpj6bIXrEoMeav7nbuqKcPLTxWEY/2icePF" \
    > /home/mockbuilder/.ssh/authorized_keys

# Passwords only for testing, remove afterward
# RUN echo "root:root" | chpasswd
# RUN echo "mockbuilder:mockbuilder" | chpasswd

# By default, there is some magic making /root to be a symlink to /var/roothome
# which is somehow ... immutable or whatever. Any attempt to create a file or
# directory inside it will fail. One of the workarounds recommended by Colin
# Walters was to remove the symlink and re-create the directory.
RUN rm /root && mkdir -m 0700 /root

# root .ssh
RUN mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh \
    && chown root:root /root/.ssh

# root authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCeTO0ddXuhDZYM9HyM0a47aeV2yIVWhTpddrQ7/RAIs99XyrsicQLABzmdMBfiZnP0FnHBF/e+2xEkT8hHJpX6bX81jjvs2bb8KP18Nh8vaXI3QospWrRygpu1tjzqZT0Llh4ZVFscum8TrMw4VWXclzdDw6x7csCBjSttqq8F3iTJtQ9XM9/5tCAAOzGBKJrsGKV1CNIrfUo5CSzY+IUVIr8XJ93IB2ZQVASK34T/49egmrWlNB32fqAbDMC+XNmobgn6gO33Yq5Ly7Dk4kqTUx2TEaqDkZfhsVu0YcwV81bmqsltRvpj6bIXrEoMeav7nbuqKcPLTxWEY/2icePF" \
    > /root/.ssh/authorized_keys

# setup 10x more fds in limits.conf
RUN cat > /etc/security/limits.d/50-copr-fds.conf <<EOF
d /var/lib/copr-rpmbuild 0775 root mock -
d /var/lib/copr-rpmbuild/results 0775 root mock -
d /var/lib/copr-rpmbuild/workspace 0775 root mock -
EOF

# Disable core dumps
RUN cat > /etc/systemd/coredump.conf <<EOF
[Coredump]
Storage=none
EOF

# TODO Remove %_install_langs from /etc/rpm/macros.image-language-conf
# Can we remove this?

# Stop and disable systemd-oomd, rhbz 2051154
RUN systemctl disable systemd-oomd

# Disable DNF makecache timer
RUN systemctl disable dnf-makecache.timer

# Disable DNF makecache service
RUN systemctl disable dnf-makecache.service

# We don't plan to apply changes (requires reboot)
RUN systemctl mask bootc-fetch-apply-updates.timer

# NetworkManager-wait-online takes too long on VMS on our hypervisors.  And we
# don't seem to need hcn-init service triggering that.
# Disable hcn-init service on ppc64le which implies NetworkManager-wait-online
# RUN systemctl disable hcn-init.service
# TODO The service isn't installed on the system, can we remove?

# TODO detect package versions
# Can we remove this?

# TODO assure up2date packages
# Can we move this to runtime?

# Set up motd for builder
RUN copr-builder help > /etc/motd || :

# We set the correct file ownership in copr-rpmbuild.spec but through some
# systemd-tmpfiles magic, it gets overwritten and the files gets owned by
# root:root. We need to explicitly tell it not to do so.
RUN cat > /etc/tmpfiles.d/copr-rpmbuild.conf <<EOF
d /var/lib/copr-rpmbuild 0775 root mock -
d /var/lib/copr-rpmbuild/results 0775 root mock -
d /var/lib/copr-rpmbuild/workspace 0775 root mock -
EOF

# Obscure hacks from praiskup/helpers
# https://github.com/praiskup/helpers/blob/main/bin/eimg-cleanup-online.in
RUN cat > /usr/lib/bootc/kargs.d/01-hacks.toml <<EOF
kargs = [
    "no_timer_check",
    "net.ifnames=0",
    "console=tty1",
    "console=ttyS0,115200n8",
]
EOF

# Transient (writable but changes are deleted on reboot) root filesystem
RUN cat >> /usr/lib/ostree/prepare-root.conf <<EOF
[root]
transient=true
EOF

# See the transient-root example
# https://gitlab.com/fedora/bootc/examples/-/blob/main/transient-root/
ENV DRACUT_NO_XATTR=1
RUN set -x; \
    kver=$(cd /usr/lib/modules && echo *); \
    dracut -vf /usr/lib/modules/$kver/initramfs.img $kver

# From praiskup/helpers eimg-prep
RUN sed -i \
    -e "s/^PasswordAuthentication.*/PasswordAuthentication yes/" \
    -e "s/#\\?PermitRootLogin.*/PermitRootLogin yes/" \
    /etc/ssh/sshd_config

# From praiskup/helpers eimg-fix-cloud-init
RUN sed -i \
    -e "s/^disable_root:.*/disable_root: 0/" \
    -e "s/^ssh_pwauth:.*/ssh_pwauth: 1/" \
    /etc/cloud/cloud.cfg

# Libvirt custom config drive
# From praiskup/helpers eimg-prep
RUN cat > /etc/rc.d/rc.local <<EOF
#! /bin/sh
set -x
set -e
touch /eimg-config-tried
test -e /dev/sr0 || exit 0
mkdir -p /config
mount /dev/sr0 /config
test -e /config/eimg-early-script.sh || { umount /config && exit 0 ; }
# This script contents is on-the-fly generated by the e.g. libvirt-new on the
# backend, and is used to configure static IPv6 addresses and such
sh -x /config/eimg-early-script.sh
EOF
RUN chmod 0755 /etc/rc.d/rc.local

# Install copr-partitions.service
# From create_swap_file.yml
COPY files/copr-partitions.service /etc/systemd/system/copr-partitions.service

# On F42 there is no /usr/local/sbin directory anymore but it is still in the
# PATH. We should use different location but at this moment, we are trying to
# be as much consistent with libvirt-new, praiskup/helpers, and provision
# playbook, as posible
RUN mkdir -p /usr/local/sbin

# Install copr-partitions.sh.
# From create_swap_file.yml
COPY files/copr-partitions.sh /usr/local/sbin/
RUN chmod 0755 /usr/local/sbin/copr-partitions.sh

# Enable copr-partitions.service
# From create_swap_file.yml
RUN systemctl enable copr-partitions

# rpm-ostree does this hack to change the location of the RPM database
# See https://coreos.github.io/rpm-ostree/#filesystem-layout
# This doesn't seem to bring any benefits in our situation and causes us
# problems with the SCM `make_srpm` method. For more details, see
# https://github.com/fedora-copr/copr/pull/3738
RUN rm /usr/lib/rpm/macros.d/macros.rpm-ostree
