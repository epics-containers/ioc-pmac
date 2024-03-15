ARG TARGET_ARCHITECTURE=linux-x86_64
ARG EPICS_HOST_ARCH=linux-x86_64
ARG IMAGE_EXT
ARG PROXY

ARG BASE=7.0.8ec2b1
ARG REGISTRY=ghcr.io/epics-containers

##### build stage ##############################################################
FROM  ${REGISTRY}/epics-base${IMAGE_EXT}-developer:${BASE} AS developer

# The devcontainer mounts the project root to /epics/generic-source
# Using the same location here makes devcontainer/runtime differences transparent.
ENV SOURCE_FOLDER=/epics/generic-source
# connect ioc source folder to its know location
RUN ln -s ${SOURCE_FOLDER}/ioc ${IOC}

# Get latest ibek while in development. Will come from epics-base when stable
COPY requirements.txt requirements.txt
RUN pip install --upgrade -r requirements.txt

WORKDIR ${SOURCE_FOLDER}/ibek-support

# copy the global ibek files
COPY ibek-support/_global/ _global

COPY ibek-support/sequencer sequencer
RUN sequencer/install.sh R2-2-9

COPY ibek-support/iocStats/ iocStats
RUN iocStats/install.sh 3.2.0

COPY ibek-support/asyn/ asyn/
RUN asyn/install.sh R4-44-2

COPY ibek-support/autosave/ autosave/
RUN autosave/install.sh R5-11

COPY ibek-support/busy/ busy/
RUN busy/install.sh R1-7-4

COPY ibek-support/sscan/ sscan/
RUN sscan/install.sh R2-11-6

COPY ibek-support/calc/ calc/
RUN calc/install.sh R3-7-5

COPY ibek-support/motor/ motor/
RUN motor/install.sh R7-3-1

COPY ibek-support/pmac/ pmac/
RUN pmac/install.sh 2-6-2b1

# get the ioc source and build it
COPY ioc ${SOURCE_FOLDER}/ioc
RUN cd ${IOC} && ./install.sh && make

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN ibek ioc extract-runtime-assets /assets ${SOURCE_FOLDER}/ibek*

##### runtime stage ############################################################
FROM ${REGISTRY}/epics-base${IMAGE_EXT}-runtime:${BASE} AS runtime

# get runtime assets from the preparation stage
COPY --from=runtime_prep /assets /

# install runtime system dependencies, collected from install.sh scripts
RUN ibek support apt-install --runtime

ENTRYPOINT ["/bin/bash", "-c", "${IOC}/start.sh"]

##### proxy stage ##############################################################
FROM ${PROXY} as proxy

# TODO - make extract-runtime-assets proxy aware and do these for us? maybe?
# TODO - YES!! in fact lets make this reuse the runtime target and get
# 'ibek support apt-install' and 'ibek ioc extract-runtime-assets' to change their
# behaviour based on TARGET_ARCHITECTURE==EPICS_HOST_ARCH
COPY --from=developer /epics/ioc /epics/ioc
COPY --from=developer ${SOURCE_FOLDER}/ibek*  ${SOURCE_FOLDER}/ibek*
COPY --from=developer /epics/*-defs /epics/

# TODO this will all be embedded in the PROXY image -remove from ioc-pmac when done
RUN pip install ibek


ENTRYPOINT ["/bin/bash", "-c", "${IOC}/config/rtems.start.sh"]
