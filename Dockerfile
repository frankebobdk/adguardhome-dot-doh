# Use the official AdGuard Home image as the base
FROM adguard/adguardhome:latest

# Install necessary packages for downloading Cloudflared
RUN apk add --no-cache curl

# Download and install Cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared

# Optional: Add any custom configuration or scripts here
# Example: Copy custom configuration files
# COPY my-custom-config.yaml /opt/adguardhome/conf/

# Expose necessary ports
EXPOSE 53/tcp 53/udp
EXPOSE 67/udp 68/tcp 68/udp
EXPOSE 80/tcp 443/tcp 443/udp 3000/tcp
EXPOSE 853/tcp
EXPOSE 784/udp 853/udp 8853/udp
EXPOSE 5443/tcp 5443/udp

# Set the entrypoint to a script that starts both AdGuard Home and Cloudflared
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
