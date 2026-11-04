#!/bin/bash

TOP=/epics/ioc
cd ${TOP}
CONFIG_DIR=${TOP}/config

# Called by the preStop hook when the pod is stopped.
# Placing your own stop.sh in the config directory will override this script.
override=${CONFIG_DIR}/stop.sh

if [[ -f ${override} ]]; then
    exec bash ${override}
fi
