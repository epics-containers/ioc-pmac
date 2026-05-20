#!/bin/bash

# wrap the console *************************************************************

if [[ -n ${KUBERNETES_PORT} && -z ${STDIO_EXPOSED} ]]; then
    STDIO_EXPOSED=YES exec stdio-socket ${IOC}/start.sh
    exit 0
fi

# error reporting **************************************************************

function ibek_error {
    echo "Error on line $BASH_LINENO: $BASH_COMMAND (exit code: $?)"

    # Wait for a bit so the container does not exit and restart continually
    sleep 10
    exit 1
}

trap ibek_error ERR

# log commands and stop on errors
set -xe

# environment setup ************************************************************

cd ${IOC}

export CONFIG_DIR=${IOC}/config
export RUNTIME_DIR=${EPICS_ROOT}/runtime
mkdir -p ${RUNTIME_DIR}

# add module paths to environment for use in ioc startup script
if [[ -f ${SUPPORT}/configure/RELEASE.shell ]]; then
    source ${SUPPORT}/configure/RELEASE.shell
fi

# check for an override start.sh script ****************************************

if [ -f ${CONFIG_DIR}/start.sh ]; then
    exec bash ${CONFIG_DIR}/start.sh
fi

# copy hand coded files to runtime folder **************************************

for f in ioc.db ioc.subst st.cmd; do
    if [ -f ${CONFIG_DIR}/${f} ]; then
        cp ${CONFIG_DIR}/${f} ${RUNTIME_DIR}/
    fi
done


# generate EPICS runtime assets ************************************************

if [[ -f ${CONFIG_DIR}/ioc.yaml ]] ; then
    ibek runtime generate2 ${CONFIG_DIR}
    ibek runtime generate-autosave
fi

# build expanded database using msi ********************************************
if [ -f ${RUNTIME_DIR}/ioc.subst ]; then
    includes=$(for i in ${SUPPORT}/*/db; do echo -n "-I $i "; done)
    bash -c "msi -o${RUNTIME_DIR}/ioc.db ${includes} -I${RUNTIME_DIR} -S${RUNTIME_DIR}/ioc.subst"
fi

# copy any streamDevice protocol files to runtime folder ***********************
# (must run AFTER `ibek runtime generate2`, which rmtrees ${RUNTIME_DIR})
if [[ -d /epics/support/configure/protocol ]] ; then
    rm -fr ${RUNTIME_DIR}/protocol
    cp -r /epics/support/configure/protocol  ${RUNTIME_DIR}
fi

# check hardware communication pre-requisites **********************************
# set IBEK_DO_WAIT_DISABLE=true to skip this step (e.g. to force IOC startup
# without waiting for hardware, or to bypass it at the shell level in pipelines
# where ibek is unavailable)
if [[ -f ${CONFIG_DIR}/ioc.yaml && "${IBEK_DO_WAIT_DISABLE}" != "true" ]]; then
    ibek ioc do-wait
fi

# Launch the IOC ***************************************************************

${IOC}/bin/linux-x86_64/ioc ${RUNTIME_DIR}/st.cmd

