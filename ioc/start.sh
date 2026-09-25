#!/bin/bash

# parse arguments *************************************************************

# --test: generate all runtime assets, but skip hardware access and the IOC
# launch. Used by CI to validate configs. All arguments, including --test,
# are also forwarded unchanged to a config override start.sh (see below) if
# one exists, for it to interpret itself.
TEST_MODE=false
[[ "$1" == "--test" ]] && TEST_MODE=true

# wrap the console *************************************************************
# test mode is not wrapped: stdio-socket takes a single command with no
# arguments and always exits 0, so a wrapped --test could never fail.

# stdio-socket runs the wrapped command as one string via `sh -c`, so the
# arguments are passed as "$*": arguments containing spaces are not supported.
if [[ -n ${KUBERNETES_PORT} && -z ${STDIO_EXPOSED} && "${TEST_MODE}" != "true" ]]; then
    STDIO_EXPOSED=YES exec stdio-socket "${IOC}/start.sh $*"
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

# report what this image was built from (support module / python versions)
if [[ -f /epics/versions.json ]]; then
    cat /epics/versions.json
fi

# check for an override start.sh script ****************************************
# this script's arguments are passed on unchanged, for the override to
# interpret itself.

if [ -f ${CONFIG_DIR}/start.sh ]; then
    exec bash "${CONFIG_DIR}/start.sh" "$@"
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
# the instance config folder is on the include path so that runtime-support
# patterns can supply their own .template / .db files alongside ioc.yaml.
if [ -f ${RUNTIME_DIR}/ioc.subst ]; then
    includes=$(for i in ${CONFIG_DIR} ${SUPPORT}/*/db; do echo -n "-I $i "; done)
    bash -c "msi -o${RUNTIME_DIR}/ioc.db ${includes} -I${RUNTIME_DIR} -S${RUNTIME_DIR}/ioc.subst"
fi

# copy any streamDevice protocol files to runtime folder ***********************
# (must run AFTER `ibek runtime generate2`, which rmtrees ${RUNTIME_DIR})
if [[ -d /epics/support/configure/protocol ]] ; then
    rm -fr ${RUNTIME_DIR}/protocol
    cp -r /epics/support/configure/protocol  ${RUNTIME_DIR}
fi

# place runtime artifacts declared in the instance config folder **************
# proto/db files vendored or dropped into config/ (e.g. by `ibek pattern add`)
# are copied into their runtime search-path locations. Runs after the support
# protocol copy above so instance files are added alongside, not wiped. This
# replaces the per-image start.sh fork (epics-containers/ioc-streamdevice#1).
if [[ -f ${CONFIG_DIR}/ioc.yaml ]] ; then
    ibek runtime place-files ${CONFIG_DIR}
fi

# check hardware communication pre-requisites **********************************
# set IBEK_DO_WAIT_DISABLE=true to skip this step (e.g. to force IOC startup
# without waiting for hardware, or to bypass it at the shell level in pipelines
# where ibek is unavailable)
# 'ibek ioc do-wait' writes /tmp/doWait_completed.txt when it finishes, and
# startup.sh waits for that file when it is used as the startup probe
# (ioc-instance startupExecutable). When do-wait is skipped, write the file
# here so the probe does not wait for ever.
if [[ -f ${CONFIG_DIR}/ioc.yaml && "${IBEK_DO_WAIT_DISABLE}" != "true" && "${TEST_MODE}" != "true" ]]; then
    ibek ioc do-wait
else
    touch /tmp/doWait_completed.txt
fi

# Launch the IOC ***************************************************************

if [[ "${TEST_MODE}" == "true" ]]; then
    echo "Test mode: all runtime assets generated successfully, skipping IOC binary launch"
else
    "${IOC}/bin/linux-x86_64/ioc" "${RUNTIME_DIR}/st.cmd"
fi
