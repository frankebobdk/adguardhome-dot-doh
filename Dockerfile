# Use the official AdGuard Home image as the base
FROM adguard/adguardhome:latest

# Install necessary packages for downloading Cloudflared, Unbound dependencies, and build tools
RUN apk update \
    && apk add --no-cache curl bash build-base libevent-dev expat-dev nghttp2-dev ca-certificates openssl-dev protobuf-c-dev \
    && rm -rf /var/cache/apk/*

# Set environment variables for Unbound installation
ENV UNBOUND_VERSION=1.20.0 \
    UNBOUND_SHA256=56b4ceed33639522000fd96775576ddf8782bb3617610715d7f1e777c5ec1dbf \
    UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-1.20.0.tar.gz

WORKDIR /tmp/src

# Download and install Unbound
RUN curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz \
    && echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - \
    && tar xzf unbound.tar.gz \
    && rm -f unbound.tar.gz \
    && cd unbound-$UNBOUND_VERSION \
    && ./configure \
        --disable-dependency-tracking \
        --prefix=/opt/unbound \
        --with-pthreads \
        --with-username=_unbound \
        --with-libevent \
        --with-libnghttp2 \
        --with-ssl \
        --enable-dnstap \
        --enable-tfo-server \
        --enable-tfo-client \
        --enable-event-api \
        --enable-subnet \
    && make install \
    && mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example \
    && apk del build-base \
    && rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

# Download and install Cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

# Download the latest root.hints file from Internic
RUN curl -o /opt/unbound/etc/unbound/root.hints https://www.internic.net/domain/named.cache

# Copy Cloudflared configuration file
COPY cloudflared/config.yml /etc/cloudflared/config.yml

# Optional: Add any custom configuration or scripts here
# Example: Copy custom configuration files for Unbound and Stubby
COPY unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf
COPY stubby/stubby.yml /etc/stubby/stubby.yml

# Expose necessary ports
EXPOSE 53/tcp 53/udp
EXPOSE 67/udp 68/tcp 68/udp
EXPOSE 80/tcp 443/tcp 443/udp 3000/tcp
EXPOSE 853/tcp 853/udp
EXPOSE 784/udp 8853/udp
EXPOSE 5053/tcp 5053/udp
EXPOSE 5153/tcp 5153/udp
EXPOSE 5253/tcp 5253/udp
EXPOSE 5443/tcp 5443/udp

# Set the entrypoint to a script that starts AdGuard Home, Cloudflared, Unbound, and Stubby
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
