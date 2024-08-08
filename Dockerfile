# Use the official AdGuard Home image as the base
FROM adguard/adguardhome:latest

# Install necessary packages for downloading Cloudflared and Unbound
RUN apk update \
    && apk add --no-cache curl bash unbound \
    && rm -rf /var/cache/apk/*

# Add edge repositories and install Stubby from edge
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
    && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk update \
    && apk add --no-cache stubby \
    && rm -rf /var/cache/apk/* \
    && sed -i '/edge/d' /etc/apk/repositories

# Download and install Cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

# Download the latest root.hints file from Internic
RUN curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache

# Copy Cloudflared configuration file
COPY cloudflared/config.yml /etc/cloudflared/config.yml

# Optional: Add any custom configuration or scripts here
# Example: Copy custom configuration files for Unbound and Stubby
COPY unbound/unbound.conf /etc/unbound/unbound.conf
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
