# Use the official AdGuard Home image as the base
FROM adguard/adguardhome:latest

# Optional: Add any custom configuration or scripts here

# Expose necessary ports
EXPOSE 53/tcp 53/udp
EXPOSE 67/udp 68/tcp 68/udp
EXPOSE 80/tcp 443/tcp 443/udp 3000/tcp
EXPOSE 853/tcp
EXPOSE 784/udp 853/udp 8853/udp
EXPOSE 5443/tcp 5443/udp

# Set the entrypoint to the default entrypoint of AdGuard Home
ENTRYPOINT ["/opt/adguardhome/AdGuardHome"]
CMD ["-c", "/opt/adguardhome/conf/AdGuardHome.yaml"]
