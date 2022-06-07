# Add support for delta tau turbo pmac 2 and power pmac
ARG MOTOR_VERSION=R7-2-3b1
ARG PMAC_VERSION=2-6-0b2
ARG IPAC_VERSION=2.16

##### build stage ##############################################################

ARG MODULES=ghcr.io/epics-containers/epics-modules:1.0.0
FROM ${MODULES} AS developer

ARG MOTOR_VERSION
ARG PMAC_VERSION
ARG IPAC_VERSION

# install additional dependecies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libssh2-1-dev \
    libboost-dev \
    && rm -rf /var/lib/apt/lists/*

# get additional support modules
RUN python3 module.py add epics-modules ipac IPAC ${IPAC_VERSION} && \
    python3 module.py add dls-controls motor MOTOR ${MOTOR_VERSION} && \
    python3 module.py add dls-controls pmac PMAC ${PMAC_VERSION}

# add CONFIG_SITE.linux
COPY CONFIG_SITE.linux-x86_64.Common ${SUPPORT}/pmac-${PMAC_VERSION}/configure

# update the generic IOC Makefile to include the new support
COPY Makefile ${IOC}/iocApp/src

# update dependencies and build the support modules and the ioc
RUN python3 module.py dependencies 
RUN make -j -C  ${SUPPORT}/motor-${MOTOR_VERSION} && \
    make -C  ${SUPPORT}/pmac-${PMAC_VERSION} && \
    make -j -C  ${IOC} && \
    make -j clean

##### runtime stage #############################################################

FROM ${MODULES}.run AS runtime

ARG MOTOR_VERSION
ARG PMAC_VERSION
ARG IPAC_VERSION

# get the products from the build stage
COPY --from=developer ${SUPPORT}/motor-${MOTOR_VERSION} ${SUPPORT}/motor-${MOTOR_VERSION}
COPY --from=developer ${SUPPORT}/pmac-${PMAC_VERSION} ${SUPPORT}/pmac-${PMAC_VERSION}
COPY --from=developer ${SUPPORT}/configure/RELEASE* ${SUPPORT}/configure/
COPY --from=developer ${IOC} ${IOC}
