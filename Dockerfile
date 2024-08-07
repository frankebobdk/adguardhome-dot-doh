# Use the official AdGuard Home image as the base
FROM adguard/adguardhome:latest

# Install necessary packages for downloading Cloudflared and Unbound
RUN apk add --no-cache curl unbound

# Download and install Cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

# Copy Cloudflared configuration file
COPY cloudflared/cloudflared.yml /etc/cloudflared/config.yml

# Optional: Add any custom configuration or scripts here
# Example: Copy custom configuration files for Unbound
COPY unbound/unbound.conf /etc/unbound/unbound.conf
#COPY unbound/root.hints /etc/unbound/root.hints

# Expose necessary ports
EXPOSE 53/tcp 53/udp
EXPOSE 67/udp 68/tcp 68/udp
EXPOSE 80/tcp 443/tcp 443/udp 3000/tcp
EXPOSE 853/tcp
EXPOSE 784/udp 853/udp 8853/udp
EXPOSE 5443/tcp 5443/udp

# Set the entrypoint to a script that starts AdGuard Home, Cloudflared, and Unbound
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
