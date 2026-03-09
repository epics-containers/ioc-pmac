#!/bin/bash
TOP=/epics/ioc
cd ${TOP}
CONFIG_DIR=${TOP}/config

set -ex

TMP_DIR=/tmp
CONFIG_DIR=/epics/ioc/config
THIS_SCRIPT=$(realpath ${0})
override=${CONFIG_DIR}/startup.sh

# 'startup.sh' may be overriden in the ioc/config directory
if [[ -f ${override} && ${override} != ${THIS_SCRIPT} ]]; then
    exec bash ${override}
fi

# confirm that the k8s ioc startup check is enabled; if not just exit successfully
if [[ ${K8S_IOC_STARTUP_ENABLED} != 'true' ]]; then
    echo "Startup check for ${IOC_NAME} currently disabled" > /proc/1/fd/1
    exit 0
fi

# check that the ibek doWait command has completed successfully
if [ -f ${TMP_DIR}/doWait_completed.txt ]; then
    exit 0
else
    exit 1
fi
