## command line options ########################################################
reuse=false

while getopts "hr" arg; do
    case $arg in
    r)
        reuse=true
        ;;
    *)
        echo "
usage: run-tests [options]

Runs a suite of tests for this module.

Options:

    -h              show this help
    -r              reuse previous build of the container (default: false)
"
        exit 0
        ;;
    esac
done

################################################################################

THIS_DIR=$(realpath $(dirname $0))
ROOT=$(realpath ${THIS_DIR}/..)

set -ex

base_args='
    --net host
    -e EPICS_CA_SERVER_PORT=7064
    ghcr.io/epics-containers/epics-base-linux-runtime:23.3.1
'

check_pv () {
    # wait for the IOC to be up and running.
    for retry in {1..5} ; do
        if podman run --rm ${base_args} caget ${1} > /tmp/pv_out.txt ; then break; fi
        sleep 1
    done

    if ! grep -q ${2} /tmp/pv_out.txt ; then
        echo "ERROR: IOC unexpected result from ${1}"
        cat /tmp/pv_out.txt
        return 1
    fi
}

check_ioc() {
    for retry in {1..5} ; do
        if podman run --rm ${base_args} caput ${1}:A 1.4; then break; fi
        sleep 1
    done
    podman run --rm ${base_args} caput ${1}:B 1.5
    sleep 0.5
    check_pv ${1}:SUM 2.9
}

config='/repos/epics/ioc/config'
ioc_args='
--security-opt label=disable
--net host
--name ioc-template-test-container
-dit
-v /tmp/tmp
ioc-template-test-image
'

#
# NOTE: to launch the IOC container for debugging these tests, use the following
# commands:
#
# podman rm -ft0 ioc-template-test-container
# podman run --net host -v $(pwd)/tests/example-ibek-config:/repos/epics/ioc/config --name ioc-template-test-container --security-opt label=disable -it ioc-template-test-image
#
# replacing "$(pwd)/tests/example-ibek-config" with a path to a different
# config folder if required. This gives you a bash prompt in the container.
#
# To start the IOC:
#   cd /repos/epics/ioc
#   ./start_ioc.sh
#

cd ${ROOT}

# build the ioc-template container for linux ###################################
if ! podman image exists ioc-template-test-image || [[ ${reuse} != "true" ]] ; then
    podman build -t ioc-template-test-image --build-arg TARGET_ARCHITECTURE=linux .
fi

# Test the default example IOC #################################################
if podman container exists ioc-template-test-container; then
    podman stop -t0 ioc-template-test-container
    podman rm -f ioc-template-test-container
fi
podman run ${ioc_args}
check_ioc "EXAMPLE"

# Test an ibek IOC #############################################################
podman stop -t0 ioc-template-test-container
podman rm -f ioc-template-test-container
podman run  -v $(pwd)/tests/example-ibek-config:${config}:ro ${ioc_args}

check_pv 'test-ibek-ioc:EPICS_VERS' 'R7.0.7'
check_ioc "EXAMPLE:IBEK"

# Test a hand coded st.cmd IOC ##################################################
podman stop -t0 ioc-template-test-container
podman rm -f ioc-template-test-container
podman run  -v $(pwd)/tests/example-config:${config}:ro ${ioc_args}

check_pv 'test-ioc:EPICS_VERS' 'R7.0.7'
check_ioc "EXAMPLE2"

# Done #########################################################################
echo
echo "All tests passed!"



