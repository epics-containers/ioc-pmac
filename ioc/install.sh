#!/bin/bash

# global install script for all support modules to reference
# every install.sh script in ibek-support should call this script
# before it compiles its support module.

THIS=$(realpath $(dirname $0))

host_cfg="${THIS}/configure/CONFIG_SITE.Common.${EPICS_HOST_ARCH}"

# for RTEMS builds don't build for the host architecture, target only
if [[ $EPICS_TARGET_ARCH == "RTEMS"* ]]; then
    touch ${host_cfg}
    sed -i '/VALID_BUILDS/d' ${host_cfg}
    echo "VALID_BUILDS=Host" >> ${host_cfg}
fi


