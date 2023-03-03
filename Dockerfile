##### build stage ##############################################################

ARG TARGET_ARCHITECTURE
ARG BASE=23.3.1

FROM  ghcr.io/epics-containers/epics-base-${TARGET_ARCHITECTURE}-developer:${BASE} AS developer

# install additional build time dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libssh2-1-dev \
    libboost-dev \
    && rm -rf /var/lib/apt/lists/*

# override of epics-base ctools may occasionally be practical
COPY ctools /ctools/
# copy the global ibek files
COPY ibek-defs/_global /ctools/_global/

# get and build depdency support modules, for each also copy associated ibek defs

COPY ibek-defs/asyn/ /ctools/asyn/
RUN python3 modules.py install ASYN R4-42 github.com/epics-modules/asyn.git --patch asyn/asyn.sh
RUN make -C ${SUPPORT}/asyn -j $(nproc)

COPY ibek-defs/autosave/ /ctools/autosave/
RUN python3 modules.py install AUTOSAVE R5-10-2 github.com/epics-modules/autosave.git --patch autosave/autosave.sh
RUN make -C ${SUPPORT}/autosave -j $(nproc)

COPY ibek-defs/busy/ /ctools/busy/
RUN python3 modules.py install BUSY R1-7-3 github.com/epics-modules/busy.git
RUN make -C ${SUPPORT}/busy -j $(nproc)

COPY ibek-defs/sscan/ /ctools/sscan/
RUN python3 modules.py install SSCAN R2-11-5 github.com/epics-modules/sscan.git
RUN make -C ${SUPPORT}/sscan -j $(nproc)

COPY ibek-defs/calc/ /ctools/calc/
RUN python3 modules.py install CALC R3-7-4 github.com/epics-modules/calc.git --patch calc/calc.sh
RUN make -C ${SUPPORT}/calc -j $(nproc)

COPY ibek-defs/motor/ /ctools/motor/
RUN python3 modules.py install MOTOR R7-2-3b1 github.com/dls-controls/motor.git
RUN make -C ${SUPPORT}/motor -j $(nproc)

COPY ibek-defs/pmac/ /ctools/pmac/
RUN python3 modules.py install PMAC 2-6-0b2 github.com/dls-controls/pmac.git --patch pmac/pmac.sh
RUN make -C ${SUPPORT}/pmac -j $(nproc)

# add the generic IOC source code. TODO: this will be generated by ibek in future
COPY ioc ${IOC}
# build generic IOC
RUN make -C ${IOC} && make clean -C ${IOC}

##### runtime preparation stage ################################################

FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
WORKDIR /min_files
RUN bash /ctools/minimize.sh ${IOC} $(ls -d ${SUPPORT}/*/) /ctools

##### runtime stage ############################################################

FROM ghcr.io/epics-containers/epics-base-${TARGET_ARCHITECTURE}-runtime:${BASE} AS runtime

# install runtime system dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    libssh2-1 \
    && rm -rf /var/lib/apt/lists/*

# add products from build stage
COPY --from=runtime_prep /min_files /