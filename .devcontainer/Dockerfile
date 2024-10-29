FROM golang:1.23.2-bullseye AS builder

RUN apt-get update && apt-get install -y \
        build-essential \
        uuid-dev \
        libgpgme-dev \
        squashfs-tools \
        libseccomp-dev \
        wget \
        pkg-config \
        git \
        cryptsetup-bin

ARG APPTAINER_COMMITISH="main"
ARG MCONFIG_OPTIONS="--without-suid"
WORKDIR $GOPATH/src/github.com/apptainer
RUN git clone https://github.com/apptainer/apptainer.git \
    && cd apptainer \
    && git checkout "$APPTAINER_COMMITISH" \
    && ./mconfig $MCONFIG_OPTIONS -p /opt/apptainer \
    && cd builddir \
    && make \
    && make install

RUN ln -s /opt/apptainer/bin/apptainer /usr/local/bin/apptainer
