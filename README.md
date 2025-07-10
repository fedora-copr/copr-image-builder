# Copr Image Builder

Please follow the instructions for building new images:
https://docs.pagure.org/copr.copr/how_to_upgrade_builders.html


## End Goals

- Building all images in hosted Image Builder instance
- Support for all architectures: x86_64, aarch64, ppc64le, and s390x
- CI/CD through Packit or GitHub actions
    - Automatic rebuilds when a relevant code is changed
    - Automatic weekly rebuilds
- At maximum 5 minutes of work to upgrade builder images in all clouds and for
  all architectures


## Where we are at

https://frostyx.cz/posts/copr-builders-powered-by-bootc
