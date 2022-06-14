#!/bin/bash

# This script locally builds the whole container dependency chain. 
# It is helpful when making changes in one of the ancestor containers 
# and testing them in the pmac generic ioc container.
# Cacheing should make this rebuild the minimum possible steps

# ASSUMPTIONS: 
#   epics-base and epics-modules are cloned into peer folders
#   all local Dockerfile FROM statements point to ${VERSION}

export VERSION=${VERSION:-$(read -p "VERSION (must be used in all FROM): " IN; echo $IN)}

# use 1st cli argument to override the target containers e.g.
#   build-local.sh ioc-pmac
if (($# > 0)); then
    targets=("$@");
else
    targets=(epics-base epics-modules ioc-pmac);
fi

set -e -x

for repo in "${targets[@]}"; do
    podman build --target developer \
        -t ghcr.io/epics-containers/"${repo}":${VERSION} \
        ../"${repo}"
    podman build \
        -t ghcr.io/epics-containers/"${repo}":${VERSION}.run \
        ../"${repo}"
done
