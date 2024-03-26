#!/bin/bash

# This script installs a python proxy for the IOC.  The proxy is used to
# communicate with the IOC from the kubernetes pod where the IOC is non-native
# and cannot run in the cluster itself.

# Only one proxy will be installed based on the EPICS_TARGET_ARCH
# the entry point for all proxies will be "epics-proxy start" and will
# be called by the default IOC start.sh script after it has prepared
# runtime assets.
# TODO: at present the rtems-proxy is the only supported proxy and uses
# rtems-proxy start as its entry point.
# TODO: consider renaming to ioc-proxy and genericizing. This would
# negate the need for this script.

# Most IOCs are native linux-x86_64 and will run directly in the cluster
# so proxy installation is not required.

if [[ $EPICS_TARGET_ARCH == "RTEMS-beatnik" ]] ; then
    pip install rtems-proxy=="0.5.0"
fi

# no other proxies supported at present
