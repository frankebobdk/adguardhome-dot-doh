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
FROM alpine:3.18

ARG BUILD_DATE
ARG VERSION
ARG VCS_REF

LABEL\
    maintainer="AdGuard Team <devteam@adguard.com>" \
    org.opencontainers.image.authors="AdGuard Team <devteam@adguard.com>" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.description="Network-wide ads & trackers blocking DNS server" \
    org.opencontainers.image.documentation="https://github.com/AdguardTeam/AdGuardHome/wiki/" \
    org.opencontainers.image.licenses="GPL-3.0" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.source="https://github.com/AdguardTeam/AdGuardHome" \
    org.opencontainers.image.title="AdGuard Home" \
    org.opencontainers.image.url="https://adguard.com/en/adguard-home/overview.html" \
    org.opencontainers.image.vendor="AdGuard" \
    org.opencontainers.image.version=$VERSION

# Update certificates.
RUN apk --no-cache add ca-certificates libcap tzdata && \
    mkdir -p /opt/adguardhome/conf /opt/adguardhome/work && \
    chown -R nobody: /opt/adguardhome

ARG DIST_DIR
ARG TARGETARCH
ARG TARGETOS
ARG TARGETVARIANT

# Ensure the DIST_DIR is set correctly to point to where the AdGuardHome binary is located
COPY --chown=nobody:nogroup \
    ${DIST_DIR}/AdGuardHome_${TARGETOS}_${TARGETARCH}${TARGETVARIANT} \
    /opt/adguardhome/AdGuardHome

RUN setcap 'cap_net_bind_service=+eip' /opt/adguardhome/AdGuardHome

# 53     : TCP, UDP : DNS
# 67     :      UDP : DHCP (server)
# 68     :      UDP : DHCP (client)
# 80     : TCP      : HTTP (main)
# 443    : TCP, UDP : HTTPS, DNS-over-HTTPS (incl. HTTP/3), DNSCrypt (main)
# 853    : TCP, UDP : DNS-over-TLS, DNS-over-QUIC
# 3000   : TCP, UDP : HTTP(S) (alt, incl. HTTP/3)
# 5443   : TCP, UDP : DNSCrypt (alt)
# 6060   : TCP      : HTTP (pprof)
EXPOSE 53/tcp 53/udp 67/udp 68/udp 80/tcp 443/tcp 443/udp 853/tcp \
    853/udp 3000/tcp 3000/udp 5443/tcp 5443/udp 6060/tcp

WORKDIR /opt/adguardhome/work

ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]

CMD [ \
    "--no-check-update", \
    "-c", "/opt/adguardhome/conf/AdGuardHome.yaml", \
    "-w", "/opt/adguardhome/work" \
]

# Copy Unbound binaries and configuration
COPY --from=unbound /usr/local/sbin/unbound* /usr/local/sbin/
COPY --from=unbound /usr/local/lib/libunbound* /usr/local/lib/
COPY --from=unbound /usr/local/etc/unbound/* /usr/local/etc/unbound/

# Copy Stubby binaries and configuration
COPY --from=stubby /usr/src/stubby/stubby /usr/local/bin/
COPY --from=stubby /usr/src/stubby/stubby.yml.example /usr/local/etc/stubby/stubby.yml

# Install necessary packages for user and group creation, and other utilities
RUN apk update && \
    apk add shadow bash nano curl wget openssl dpkg

RUN mkdir -p /usr/local/etc/unbound && \
    mkdir -p /usr/local/etc/stubby

ADD scripts /temp

RUN groupadd unbound && \
    useradd -g unbound unbound && \
    /bin/bash /temp/install.sh && \
    rm -rf /temp/install.sh 

VOLUME ["/config"]

RUN echo "$(date "+%d.%m.%Y %T") Built from ${FRM} with tag ${TAG}" >> /build_date.info
