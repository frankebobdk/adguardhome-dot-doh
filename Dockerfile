# Stage 1: Build Unbound
FROM debian:bullseye as unbound

ARG UNBOUND_VERSION=1.20.0
ARG UNBOUND_SHA256=56b4ceed33639522000fd96775576ddf8782bb3617610715d7f1e777c5ec1dbf
ARG UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-1.20.0.tar.gz

WORKDIR /tmp/src

RUN build_deps="curl gcc libc-dev libevent-dev libexpat1-dev libnghttp2-dev make libssl-dev" && \
    set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      $build_deps \
      bsdmainutils \
      ca-certificates \
      ldnsutils \
      libevent-2.1-7 \
      libexpat1 \
      libprotobuf-c-dev \
      protobuf-c-compiler && \
    curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-${UNBOUND_VERSION} && \
    groupadd unbound && \
    useradd -g unbound -s /dev/null -d /etc unbound && \
    ./configure \
        --disable-dependency-tracking \
        --with-pthreads \
        --with-username=unbound \
        --with-libevent \
        --with-libnghttp2 \
        --enable-dnstap \
        --enable-tfo-server \
        --enable-tfo-client \
        --enable-event-api \
        --enable-subnet && \
    make -j$(nproc) install && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

# Stage 2: Build Stubby
FROM debian:bullseye as stubby

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get -y install \
      autoconf \
      build-essential \
      ca-certificates \
      cmake \
      git \
      libgetdns-dev \
      libidn2-0-dev \
      libssl-dev \
      libunbound-dev \
      libyaml-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/

WORKDIR /usr/src/stubby
RUN git clone https://github.com/getdnsapi/stubby.git . && \
    git checkout tags/v0.4.0 && \
    cmake . && \
    make

# Stage 3: Main stage for AdGuard Home
FROM adguard/adguardhome:latest
ARG FRM
ARG TAG
ARG TARGETPLATFORM

# Copy Unbound binaries and configuration
COPY --from=unbound /usr/local/sbin/unbound* /usr/local/sbin/
COPY --from=unbound /usr/local/lib/libunbound* /usr/local/lib/
COPY --from=unbound /usr/local/etc/unbound/* /usr/local/etc/unbound/

# Copy Stubby binaries and configuration
COPY --from=stubby /usr/src/stubby/stubby /usr/local/bin/
COPY --from=stubby /usr/src/stubby/stubby.yml.example /usr/local/etc/stubby/stubby.yml

RUN mkdir -p /usr/local/etc/unbound && \
    mkdir -p /usr/local/etc/stubby

# Install necessary packages for user and group creation, and other utilities
RUN apk update && \
    apk add shadow bash nano curl wget openssl

ADD scripts /temp

RUN groupadd unbound && \
    useradd -g unbound unbound && \
    /bin/bash /temp/install.sh && \
    rm -rf /temp/install.sh 

VOLUME ["/config"]

RUN echo "$(date "+%d.%m.%Y %T") Built from ${FRM} with tag ${TAG}" >> /build_date.info
