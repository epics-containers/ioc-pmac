ARG IMAGE_EXT

ARG BASE=7.0.9ec3
ARG REGISTRY=ghcr.io/epics-containers
ARG RUNTIME=${REGISTRY}/epics-base${IMAGE_EXT}-runtime:${BASE}
ARG DEVELOPER=${REGISTRY}/epics-base${IMAGE_EXT}-developer:${BASE}

##### build stage ##############################################################
FROM  ${DEVELOPER} AS developer

# The devcontainer mounts the project root to /epics/generic-source
# Using the same location here makes devcontainer/runtime differences transparent.
ENV SOURCE_FOLDER=/epics/generic-source
# connect ioc source folder to its know location
RUN ln -s ${SOURCE_FOLDER}/ioc ${IOC}

# Get the current version of ibek
COPY requirements.txt requirements.txt
RUN pip install --upgrade -r requirements.txt

WORKDIR ${SOURCE_FOLDER}/ibek-support

COPY ibek-support/_ansible _ansible
ENV PATH=$PATH:${SOURCE_FOLDER}/ibek-support/_ansible

COPY ibek-support/iocStats/ iocStats
RUN ansible.sh iocStats

COPY ibek-support/asyn/ asyn
RUN ansible.sh asyn

COPY ibek-support/busy/ busy
RUN ansible.sh busy

COPY ibek-support/pvlogging/ pvlogging/
RUN ansible.sh pvlogging

COPY ibek-support/sscan/ sscan
RUN ansible.sh sscan

COPY ibek-support/calc/ calc
RUN ansible.sh calc

COPY ibek-support/autosave/ autosave
RUN ansible.sh autosave

COPY ibek-support/motor/ motor/
RUN ansible.sh motor

COPY ibek-support/pmac/ pmac/
RUN ansible.sh pmac

# get the ioc source and build it
COPY ioc ${SOURCE_FOLDER}/ioc
RUN ansible.sh ioc

# install runtime proxy for non-native builds
RUN bash ${IOC}/install_proxy.sh

# TODO this is to make autosave work for non-root users at runtime.
# but in general having /epics writable is useful - think on how to do this better
RUN chmod a+w /epics/ -R

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
# TODO /epics/autosave should be a built in for extract-runtime-assets
RUN ibek ioc extract-runtime-assets /assets /epics/autosave

##### runtime stage ############################################################
FROM ${RUNTIME} AS runtime

# get runtime assets from the preparation stage
COPY --from=runtime_prep /assets /

# TODO this is to make autosave work for non-root users at runtime.
# but in general having /epics writable is useful - think on how to do this better
RUN chmod a+w /epics/ -R

# install runtime system dependencies, collected from install.sh scripts
RUN ibek support apt-install-runtime-packages --skip-non-native

CMD ["bash", "-c", "${IOC}/start.sh"]
