# Stage 1: Build AdGuardHome
FROM golang:alpine AS build_adguard

RUN apk add --update git make build-base npm && \
    rm -rf /var/cache/apk/*

WORKDIR /src/AdGuardHome
COPY . /src/AdGuardHome
RUN make

# Stage 2: Build Stubby
FROM alpine AS build_stubby

RUN apk add --update alpine-sdk libidn2-dev unbound-dev cmake openssl-dev libev-dev libuv-dev check-dev yaml-dev && \
    git clone https://github.com/getdnsapi/getdns.git && \
    cd getdns && git checkout master && git submodule update --init && \
    mkdir build && cd build && \
    cmake -DBUILD_STUBBY=ON .. && \
    make && make install

# Stage 3: Final image
FROM alpine:latest
LABEL maintainer="AdGuard Team <devteam@adguard.com>"

# Install dependencies and update CA certs
RUN apk update && apk add --no-cache \
    ca-certificates bash libidn2 libcrypto3 openssl yaml unbound wget && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /opt/adguardhome && \
    mkdir -p /usr/local/var/run

# Copy AdGuardHome binary from build stage
COPY --from=build_adguard /src/AdGuardHome/AdGuardHome /opt/adguardhome/AdGuardHome

# Install Stubby from previous build
COPY --from=build_stubby /usr/local/lib/libgetdns.so.10.2.0 /usr/local/lib/libgetdns.so
COPY --from=build_stubby /usr/local/bin/stubby /usr/local/bin/stubby
COPY --from=build_stubby /usr/local/share/man/man1/stubby.1 /usr/local/share/man/man1/stubby.1
COPY --from=build_stubby /usr/local/share/doc/stubby/AUTHORS /usr/local/share/doc/stubby/AUTHORS
COPY --from=build_stubby /usr/local/share/doc/stubby/COPYING /usr/local/share/doc/stubby/COPYING
COPY --from=build_stubby /usr/local/share/doc/stubby/ChangeLog /usr/local/share/doc/stubby/ChangeLog
COPY --from=build_stubby /usr/local/share/doc/stubby/NEWS /usr/local/share/doc/stubby/NEWS
COPY --from=build_stubby /usr/local/share/doc/stubby/README.md /usr/local/share/doc/stubby/README.md

# Copy the config file for Stubby
COPY scripts/stubby.yml /usr/local/etc/stubby/stubby.yml

# Download and install Cloudflare depending on the architecture
RUN set -eux; \
    ARCH="$(apk --print-arch)"; \
    case "$ARCH" in \
        aarch64|arm64) \
            CLOUDFLARE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"; \
            ;; \
        armhf|arm) \
            CLOUDFLARE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"; \
            ;; \
        x86_64) \
            CLOUDFLARE_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"; \
            ;; \
        *) \
            echo "Unsupported architecture: $ARCH"; \
            exit 1; \
            ;; \
    esac; \
    wget -qO /usr/local/bin/cloudflared "${CLOUDFLARE_URL}"; \
    chmod +x /usr/local/bin/cloudflared; \
    cloudflared --version

# Add user cloudflared and set ownership
RUN addgroup -S cloudflared && \
    adduser -S cloudflared -G cloudflared -s /sbin/nologin -D -H && \
    chown cloudflared:cloudflared /usr/local/bin/cloudflared

# Get root.hints file for Unbound
RUN wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root

# Set up the Unbound conf file
COPY scripts/unbound.conf /etc/unbound/unbound.conf

# Copy the entrypoint script
COPY scripts/entrypoint.sh /opt/

# Copy the config file for cloudflared
COPY scripts/cloudflared.yml /opt/cloudflared/config.yml

# Set script permissions executable
RUN chmod +x /opt/entrypoint.sh

# Expose ports
EXPOSE 53/tcp 53/udp 67/udp 68/udp 80/tcp 443/tcp 443/udp 853/tcp 3000/tcp 5053/tcp 5053/udp 5153/tcp 5153/udp 5253/tcp 5253/udp

# Define volumes
VOLUME ["/opt/adguardhome/conf", "/opt/adguardhome/work", "/opt/unbound", "/opt/stubby"]

# Run the entrypoint script
ENTRYPOINT ["/opt/entrypoint.sh"]
