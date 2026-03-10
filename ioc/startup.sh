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

# Wait for the ibek doWait command to have completed successfully.
# Such loop prevents the pod to report failed k8s startup probe events unecessarily
# (i.e. by exiting and trying again) while the IOC is still in the process of starting up.
while [ ! -f ${TMP_DIR}/doWait_completed.txt ]; do
    sleep 1
done

exit 0
