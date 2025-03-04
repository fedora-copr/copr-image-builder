# This Dockerfile is based on an ansible playbook for provisioning Copr builders
# https://pagure.io/fedora-infra/ansible/blob/main/f/roles/copr/backend/files/provision/provision_builder_tasks.yml
# First we build an image from this Dockerfile, then we use Image Builder
# config.toml blueprint to finish the image.

FROM quay.io/fedora/fedora-bootc:41

# The config.toml blueprint installs all needed packages but we need to have
# copr-builder installed even before that because several commands in this
# Dockerfile use scripts provided by that package
RUN dnf -y install copr-builder && dnf -y clean all

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

# Fallback to the legacy crypto policies
# https://fedoraproject.org/wiki/Changes/StrongCryptoSettings
RUN update-crypto-policies --set DEFAULT:SHA1

# TODO Collect facts about builder hardware
# We can probably skip this, it looks like starting_builder task

# Run /bin/copr-update-builder from copr-builder package
RUN /usr/bin/copr-update-builder

# Disable core dumps
RUN echo "[Coredump]\nStorage=none" >> /etc/systemd/coredump.conf

# TODO Remove %_install_langs from /etc/rpm/macros.image-language-conf
# Can we remove this?

# TODO detect package versions
# Can we remove this?

# TODO assure up2date packages
# Can we move this to runtime?

# Set up motd for builder
RUN copr-builder help > /etc/motd || :
