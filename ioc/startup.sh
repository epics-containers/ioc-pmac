#!/bin/bash
TOP=/epics/ioc
cd ${TOP}
CONFIG_DIR=${TOP}/config

set -e

TMP_DIR=/tmp
THIS_SCRIPT=$(realpath ${0})
override=${CONFIG_DIR}/startup.sh

# 'startup.sh' may be overridden in the ioc/config directory
# compare resolved paths: /epics/ioc is a symlink, so an unresolved override
# path never equals THIS_SCRIPT and a copied script would exec itself forever
if [[ -f ${override} && $(realpath "${override}") != "${THIS_SCRIPT}" ]]; then
    exec bash ${override}
fi

# Startup probe: succeed only once the IOC is up and serving Channel Access.
#
# Kubernetes marks the pod Ready only after this probe succeeds, and holds off
# the liveness probe until then. So an IOC that keeps failing during startup
# stays NotReady instead of flapping between Ready and NotReady on every
# restart, and a slow IOC is not killed by the liveness probe while it starts.

# 1. wait for 'ibek ioc do-wait' (hardware pre-requisites) to complete
while [ ! -f ${TMP_DIR}/doWait_completed.txt ]; do
    sleep 1
done

# 2. wait for the IOC to answer on the same PV that liveness.sh checks
K8S_IOC_PV=${K8S_IOC_PV:-"${IOC_PREFIX^^}:UPTIME"}
K8S_IOC_PORT=${K8S_IOC_PORT:-5064}
export EPICS_CA_ADDR_LIST=${K8S_IOC_ADDRESS}
export EPICS_CA_SERVER_PORT=${K8S_IOC_PORT}

until caget -w 1 ${K8S_IOC_PV} >/dev/null 2>&1; do
    sleep 1
done

exit 0
