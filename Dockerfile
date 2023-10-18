ARG TARGET_ARCHITECTURE
ARG BASE=7.0.7ec2
ARG REGISTRY=ghcr.io/epics-containers

##### build stage ##############################################################

FROM  ${REGISTRY}/epics-base-${TARGET_ARCHITECTURE}-developer:${BASE} AS developer

# Get latest ibek while in development. Will come from epics-base in future.
RUN pip install --upgrade ibek==1.4.0

# The devcontainer mounts the project root to /epics/ioc-adsimdetector. Using
# the same location here makes devcontainer/runtime differences transparent.
WORKDIR /epics/ioc-pmac/ibek-support

# copy the global ibek files
COPY ibek-support/_global/ _global

COPY ibek-support/iocStats/ iocStats
RUN iocStats/install.sh 3.1.16

COPY ibek-support/asyn/ asyn/
RUN asyn/install.sh R4-42

COPY ibek-support/autosave/ autosave/
RUN autosave/install.sh R5-10-2

COPY ibek-support/busy/ busy/
RUN busy/install.sh R1-7-3

COPY ibek-support/sscan/ sscan/
RUN sscan/install.sh R2-11-6

COPY ibek-support/calc/ calc/
RUN calc/install.sh R3-7-5

COPY ibek-support/motor/ motor/
RUN motor/install.sh R7-2-3b1

COPY ibek-support/pmac/ pmac/
RUN pmac/install.sh 2-4-10

# Generate template IOC source tree / generate Makefile / compile
RUN ibek ioc build

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
RUN ibek ioc extract-runtime-assets /assets

##### runtime stage ############################################################

FROM ${REGISTRY}/epics-base-${TARGET_ARCHITECTURE}-runtime:${BASE} AS runtime

# get runtime assets from the preparation stage
COPY --from=runtime_prep /assets /

# install runtime system dependencies, collected from install.sh scripts
RUN ibek support apt-install --runtime

ENV TARGET_ARCHITECTURE ${TARGET_ARCHITECTURE}

ENTRYPOINT ["/bin/bash", "-c", "${IOC}/start.sh"]