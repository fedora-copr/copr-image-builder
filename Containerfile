# This Dockerfile is based on an ansible playbook for provisioning Copr builders
# https://pagure.io/fedora-infra/ansible/blob/main/f/roles/copr/backend/files/provision/provision_builder_tasks.yml
# First we build an image from this Dockerfile, then we use Image Builder
# config.toml blueprint to finish the image.

FROM quay.io/fedora/fedora-bootc:41

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
RUN cat > /etc/yum.repos.d/infra-tags.repo <<EOF
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

# TODO Can we use some syntax that would allow comments for the packages?
RUN dnf -y install \
    subscription-manager \
    copr-builder \
    python3-copr-common \
    rpmlint \
    tito \
    fedora-review \
    bc \
    pyp2spec \
    && dnf -y clean all

# TODO Collect facts about builder hardware
# We can probably skip this, it looks like starting_builder task

# Run /bin/copr-update-builder from copr-builder package
RUN /usr/bin/copr-update-builder

# mockbuild user
# TODO Password only for testing, remove afterward
RUN useradd mockbuilder -G mock -p mockbuilder

# mockbuilder .ssh
RUN mkdir /home/mockbuilder/.ssh \
    && chmod 0700 /home/mockbuilder/.ssh \
    && chown mockbuilder:mockbuilder /home/mockbuilder/.ssh

# mockbuilder authorized_keys
RUN echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCeTO0ddXuhDZYM9HyM0a47aeV2yIVWhTpddrQ7/RAIs99XyrsicQLABzmdMBfiZnP0FnHBF/e+2xEkT8hHJpX6bX81jjvs2bb8KP18Nh8vaXI3QospWrRygpu1tjzqZT0Llh4ZVFscum8TrMw4VWXclzdDw6x7csCBjSttqq8F3iTJtQ9XM9/5tCAAOzGBKJrsGKV1CNIrfUo5CSzY+IUVIr8XJ93IB2ZQVASK34T/49egmrWlNB32fqAbDMC+XNmobgn6gO33Yq5Ly7Dk4kqTUx2TEaqDkZfhsVu0YcwV81bmqsltRvpj6bIXrEoMeav7nbuqKcPLTxWEY/2icePF" \
    > /home/mockbuilder/.ssh/authorized_keys

# TODO Password only for testing, remove afterward
RUN echo "root:root" | chpasswd

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

# Disable DNF makecache timer
# Disable DNF makecache service
# Disable hcn-init service on ppc64le which implies NetworkManager-wait-online
# Stop and disable systemd-oomd, rhbz 2051154
# [customizations.services]
# disabled = [
#     "systemd-oomd",
#     "dnf-makecache.timer",
#     "dnf-makecache.service",
#     "hcn-init.service",
# ]
RUN systemctl disable systemd-oomd

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
