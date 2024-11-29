#!/bin/bash

# A launcher for the phoebus to view the generated OPIs

thisdir=$(realpath $(dirname $0))
workspace=$(realpath ${thisdir}/..)

settings="
-resource ${workspace}/opi/auto-generated/index.bob
-settings ${workspace}/opi/settings.ini
"

if which phoebus.sh &>/dev/null ; then
    echo "Using phoebus.sh from PATH"
    set -x
    phoebus.sh ${settings} "${@}"

elif module load phoebus 2>/dev/null; then
    echo "Using phoebus module"
    set -x
    phoebus.sh ${settings} "${@}"

else
    echo "No local phoebus install found, using a container"

    if podman version &> /dev/null && [[ -z $USE_DOCKER ]] ;
        then docker=podman
        else docker=docker
    fi
    echo "Using $docker as container runtime"

    # ensure local container users can access X11 server
    xhost +SI:localuser:$(id -un)

    # settings for container launch
    x11="-e DISPLAY --net host"
    args=$"--rm -it --security-opt=label=none"
    mounts="-v=/tmp:/tmp -v=${workspace}:/workspace"
    image="ghcr.io/epics-containers/ec-phoebus:latest"

    settings="
    -settings /workspace/opi/settings.ini
    -resource /workspace/opi/auto-generated/index.bob
    "

    set -x
    $docker run ${mounts} ${args} ${x11} ${image} ${settings} "${@}"

fi
