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

# use DOCKER_PROVIDER if it is set (kodman on GitLab CI), otherwise prefer docker
# but use podman if USE_PODMAN is set
if [[ -n $DOCKER_PROVIDER ]]
    then docker=$DOCKER_PROVIDER
elif docker version &> /dev/null && [[ -z $USE_PODMAN ]]
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
opts="--rm"
# kodman runs a pod, which has no SELinux option to pass
if [[ $(basename ${docker}) != kodman ]]; then opts+=" --security-opt=label=disable"; fi

# run a command line in the image: kodman has no -e, so the command line carries
# its own environment, which works the same for docker and podman
run_in_image() {
    $docker run ${opts} ${mounts} --entrypoint bash ${TAG} -c "$1" 2>&1
}

# STDIO_EXPOSED stops start.sh re-executing through stdio-socket inside a pod
# (e.g. kodman on GitLab CI): the IOC must see the end of stdin and exit
result=$(run_in_image "STDIO_EXPOSED=YES /epics/ioc/start.sh")

# check that the IOC output expected results
if echo "${result}" | grep -i error; then
    echo "ERROR: errors in IOC startup"
    exit 1
elif [[ ! ${result} =~ "5.15" || ! ${result} =~ "/epics/runtime/st.cmd" ]]; then
    echo "ERROR: dbgf output not as expected"
    exit 1
fi

# verify --test mode generates runtime assets but does not launch the IOC binary.
# KUBERNETES_PORT is set as it is inside a pod (e.g. kodman on GitLab CI), to
# show that --test does not re-exec through stdio-socket there.
test_result=$(run_in_image "KUBERNETES_PORT=tcp://ci:443 /epics/ioc/start.sh --test")

if echo "${test_result}" | grep -i error; then
    echo "ERROR: errors in IOC --test startup"
    exit 1
elif ! echo "${test_result}" | grep -q "Test mode:"; then
    echo "ERROR: --test did not report test mode"
    exit 1
fi

echo "Tests passed!"
