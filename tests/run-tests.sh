#!/bin/bash

# test script for ioc-template to verify that the container loads and the
# generic IOC will start - demonstrating that the correct runtime libraries
# all present and correct and that mounting IOC config or ibek config
# works as expected.

THIS=$(realpath $(dirname $0))
ROOT=$(realpath ${THIS}/..)
CONF=/epics/ioc/config

# log commands and stop on errorsr
set -ex

# use docker if available else use podman
if ! docker version &>/dev/null; then alias docker=podman; fi

cd ${ROOT}

# if a tag was passed in this implies it was already built
export TAG=${TAG:-ec_test}
if [[ ${TAG} == "ec_test" ]] ; then TARGET=runtime ./build; fi

# try out a test ibek config IOC instance with the generic IOC
result=$(docker run --rm -v ${THIS}/config:${CONF} ${TAG} /epics/ioc/start.sh 2>&1)

# check that the IOC output expected results
if echo "${result}" | grep -i error; then
    echo "ERROR: errors in IOC startup"
    exit 1
elif [[ ! ${result} =~ "5.15" || ! ${result} =~ "/epics/runtime/st.cmd" ]]; then
    echo "ERROR: dbgf output not as expected"
    exit 1
fi

echo "Tests passed!"



