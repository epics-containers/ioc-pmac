#!/bin/bash

# a termination script which will be called as part of the pods termination
# in the preStop lifecycle hook. At present this script has no function
# except that behaviour can be added by placing a stop.sh script in the
# config directory.

TOP=/repos/epics/ioc
cd ${TOP}
CONFIG_DIR=${TOP}/config

override=${CONFIG_DIR}/stop.sh

if [[ -f ${override} ]]; then
    exec bash ${override}
elif [[ ${RTEMS_VME_AUTO_REBOOT} == 'true' ]] ; then
    # This is a placeholder for a script that is called when the pod is stopped.
    # Placing your own stop.sh in the config directory will override this script.

    # No action is required here for RTEMS because the start.sh script will
    # monitor for SIG_TERM and reboot the IOC when it is received.
fi


