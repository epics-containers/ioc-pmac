#!/bin/bash
# Readiness probe for IOC instances.
#
# The IOC is Ready once its liveness PV answers over Channel Access. This
# stops a pod that crashes during startup (e.g. its device is powered off)
# from briefly reporting Ready on every restart, which makes the StatefulSet
# replica alerts resolve and re-fire on each crash loop.
#
# Enable it in the instance values.yaml (note the ioc-instance: parent key;
# the chart silently ignores these keys at the top level), for example:
#   ioc-instance:
#     readinessExecutable: /epics/ioc/readiness.sh
# or, to require the PV to stay up for several checks before Ready:
#   ioc-instance:
#     readinessProbe:
#       exec:
#         command: [/bin/bash, /epics/ioc/readiness.sh]
#       periodSeconds: 10
#       successThreshold: 3
#
# With hostNetwork: false, a pod that is not Ready is removed from its
# Service endpoints, so in-cluster clients using the Service cannot reach
# the IOC until this probe passes.

TOP=/epics/ioc
cd ${TOP} || exit 1

CONFIG_DIR=${TOP}/config
THIS_SCRIPT=$(realpath ${0})
override=${CONFIG_DIR}/readiness.sh

# compare resolved paths: /epics/ioc is a symlink, so an unresolved override
# path never equals THIS_SCRIPT and a copied script would exec itself forever
if [[ -f ${override} && $(realpath "${override}") != "${THIS_SCRIPT}" ]]; then
    exec bash ${override}
fi

# use the same PV and CA settings as liveness.sh, including their overrides
K8S_IOC_PV=${K8S_IOC_PV:-"${IOC_PREFIX^^}:UPTIME"}
K8S_IOC_PORT=${K8S_IOC_PORT:-5064}

export EPICS_CA_ADDR_LIST=${K8S_IOC_ADDRESS}
export EPICS_CA_SERVER_PORT=${K8S_IOC_PORT}

# not ready is the normal state while the IOC starts, so unlike liveness.sh
# this does not write to the IOC's log on failure
caget ${K8S_IOC_PV} > /dev/null 2>&1
