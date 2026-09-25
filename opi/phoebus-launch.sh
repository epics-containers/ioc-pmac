#!/bin/bash

#Comment out this variable if you want to use your local phoebus
use_container=1

# A launcher for the phoebus to view the generated OPIs

thisdir=$(realpath $(dirname $0))
workspace=$(realpath ${thisdir}/..)

# update settings.ini with CA and PVA ports
cat ${workspace}/opi/settings.ini |
    sed -r \
    -e "s|5064|${EPICS_CA_SERVER_PORT:-5064}|" \
    -e "s|5075|${EPICS_PVA_SERVER_PORT:-5075}|" \
    -e "s|5065|${EPICS_CA_REPEATER_PORT:-5065}|" > /tmp/settings.ini

settings="
-resource ${workspace}/opi/auto-generated/index.bob
-settings /tmp/settings.ini
-server 2200
"

if which phoebus.sh &>/dev/null && [[ -z ${use_container} ]] ; then
    echo "Using phoebus.sh from PATH"
    set -x
    phoebus.sh ${settings} "${@}"

elif module load phoebus 2>/dev/null && [[ -z ${use_container} ]] ; then
    echo "Using phoebus module"
    set -x
    phoebus.sh ${settings} "${@}"

else
    echo "No local phoebus install found, using a container"

    # prefer podman but use docker if USE_DOCKER is set
    if podman version &> /dev/null && [[ -z $USE_DOCKER ]]
        then docker=podman; UIDGID=0:0
        else docker=docker; UIDGID=$(id -u):$(id -g); xhost +SI:localuser:$(id -un)
    fi
    echo "Using $docker as container runtime"


    # settings for container launch
    x11="-e DISPLAY --net host"
    args="--rm -it --security-opt=label=disable --user ${UIDGID}"
    mounts="-v=/tmp:/tmp -v=${workspace}:/workspace -v=${workspace}/..:/workspaces"
    image="ghcr.io/epics-containers/ec-phoebus:latest"

    # pass the host's time zone into the container so that times (e.g. data
    # browser plot axes) are local rather than the container default of UTC.
    # Java reads the TZ environment variable first and resolves zone names from
    # its own tz database. (Bind-mounting /etc/localtime, or podman --tz=local,
    # does not help: in the image /etc/localtime is a symlink, so both land on
    # its target and the JDK still reads the symlink name Etc/UTC.)
    host_tz=${TZ:-$(timedatectl show -p Timezone --value 2>/dev/null || true)}
    if [[ -z ${host_tz} && -L /etc/localtime ]]; then
        host_tz=$(readlink -f /etc/localtime | sed -n 's|.*/zoneinfo/||p')
    fi
    if [[ -z ${host_tz} && -r /etc/timezone ]]; then
        # the zone name Debian/Ubuntu keep alongside /etc/localtime
        host_tz=$(head -n 1 /etc/timezone)
    fi
    if [[ -n ${host_tz} ]]; then
        args="${args} -e TZ=${host_tz}"
    else
        echo "WARNING: could not determine the host time zone, times will be UTC." \
            "Run with e.g. TZ=Europe/London bash ${0}" >&2
    fi

    settings="
    -resource /workspace/opi/auto-generated/index.bob
    -settings /tmp/settings.ini
    -server 2200
    "

    set -x
    $docker run ${mounts} ${args} ${x11} ${image} ${settings} "${@}"

fi
