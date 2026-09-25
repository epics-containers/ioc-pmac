#!/bin/bash

# test script for ioc-template to verify that the container loads and the
# generic IOC will start - demonstrating that the correct runtime libraries
# all present and correct and that mounting IOC config or ibek config
# works as expected.

TAG=${1} # pass a tag on the command line to test a prebuilt image
THIS=$(realpath $(dirname $0))
ROOT=$(realpath ${THIS}/..)
CONF=/epics/ioc/config

# log commands and stop on errorsr
set -ex

# prefer docker but use podman if USE_PODMAN is set
if docker version &> /dev/null && [[ -z $USE_PODMAN ]]
    then docker=docker
    else docker=podman
fi

cd ${ROOT}

# if a tag was passed in this implies it was already built
export TAG=${TAG:-ec_test}
if [[ ${TAG} == "ec_test" ]] ; then TARGET=runtime ./build; fi

# try out a test ibek config IOC instance with the generic IOC
mounts=" -v ${THIS}/config:${CONF}:ro"
# allows local testing of a modified start.sh script
mounts+=" -v ${ROOT}/ioc/start.sh:/epics/ioc/start.sh:ro"
opts="--rm --security-opt=label=disable"
result=$($docker run ${opts} ${mounts} ${TAG} /epics/ioc/start.sh 2>&1)

# check that the IOC output expected results
if echo "${result}" | grep -i error; then
    echo "ERROR: errors in IOC startup"
    exit 1
elif [[ ! ${result} =~ "5.15" || ! ${result} =~ "/epics/runtime/st.cmd" ]]; then
    echo "ERROR: dbgf output not as expected"
    exit 1
fi

# verify --test mode generates runtime assets but does not launch the IOC binary.
# KUBERNETES_PORT is set as it is inside a pod (e.g. kodman on GitLab CI),
# where start.sh would otherwise re-exec through stdio-socket.
test_result=$($docker run ${opts} -e KUBERNETES_PORT=tcp://ci:443 ${mounts} ${TAG} /epics/ioc/start.sh --test 2>&1)

if echo "${test_result}" | grep -i error; then
    echo "ERROR: errors in IOC --test startup"
    exit 1
elif ! echo "${test_result}" | grep -q "Test mode:"; then
    echo "ERROR: --test did not report test mode"
    exit 1
fi

echo "Tests passed!"
