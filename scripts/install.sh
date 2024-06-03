#!/bin/bash

# Clean stubby config
mkdir -p /etc/stubby \
    && rm -f /etc/stubby/stubby.yml

# Detect architecture
if command -v dpkg > /dev/null; then
  ARCH="$(dpkg --print-architecture | awk -F'-' '{print $NF}')"
elif command -v apk > /dev/null; then
  ARCH="$(apk --print-arch)"
else
  echo "Unsupported architecture"
  exit 1
fi

# Determine Cloudflare package based on architecture
case "$ARCH" in
    aarch64|arm64)
        CF_PACKAGE="cloudflared-linux-arm64.deb"
        ;;
    arm)
        CF_PACKAGE="cloudflared-linux-arm.deb"
        ;;
    armhf)
        CF_PACKAGE="cloudflared-linux-armhf.deb"
        ;;
    amd64|x86_64)
        CF_PACKAGE="cloudflared-linux-amd64.deb"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Install Cloudflare
cd /tmp \
&& wget https://github.com/cloudflare/cloudflared/releases/latest/download/${CF_PACKAGE} \
&& apk add --no-cache dpkg \
&& dpkg -i ./${CF_PACKAGE} \
&& rm -f ./${CF_PACKAGE} \
&& echo "$(date "+%d.%m.%Y %T") $(cloudflared -V) installed for ${ARCH}" >> /build_date.info

# Add cloudflared user
useradd -s /usr/sbin/nologin -r -M cloudflared \
    && chown cloudflared:cloudflared /usr/local/bin/cloudflared

# Clean cloudflared config
mkdir -p /etc/cloudflared \
    && rm -f /etc/cloudflared/config.yml

# Add unbound version to build.info
echo "$(date "+%d.%m.%Y %T") Unbound $(unbound -V | head -1) installed for ${ARCH}" >> /build_date.info    

# Clean up
apk -y autoremove \
    && apk -y autoclean \
    && apk -y clean \
    && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*

# Create AdGuard Home service directory
mkdir -p /etc/services.d/adguardhome

# run file
echo '#!/usr/bin/env bash' | tee /etc/services.d/adguardhome/run
# Run unbound in the background
echo 's6-echo "Starting unbound"' | tee -a /etc/services.d/adguardhome/run
echo '/usr/local/sbin/unbound -p -c /config/unbound.conf' | tee -a /etc/services.d/adguardhome/run
# Run stubby in the background
echo 's6-echo "Starting stubby"' | tee -a /etc/services.d/adguardhome/run
echo 'stubby -g -C /config/stubby.yml' | tee -a /etc/services.d/adguardhome/run
# Run AdGuard Home in the foreground
echo 's6-echo "Starting AdGuard Home"' | tee -a /etc/services.d/adguardhome/run
echo '/opt/adguardhome/AdGuardHome --config /config/AdGuardHome.yaml' | tee -a /etc/services.d/adguardhome/run
chmod 755 /etc/services.d/adguardhome/run

# finish file
echo '#!/usr/bin/env bash' | tee /etc/services.d/adguardhome/finish
echo 's6-echo "Stopping stubby"' | tee -a /etc/services.d/adguardhome/finish
echo 'killall -9 stubby' | tee -a /etc/services.d/adguardhome/finish
echo 's6-echo "Stopping cloudflared"' | tee -a /etc/services.d/adguardhome/finish
echo 'killall -9 cloudflared' | tee -a /etc/services.d/adguardhome/finish
echo 's6-echo "Stopping unbound"' | tee -a /etc/services.d/adguardhome/finish
echo 'killall -9 unbound' | tee -a /etc/services.d/adguardhome/finish
chmod 755 /etc/services.d/adguardhome/finish

# Create oneshot for unbound
mkdir -p /etc/cont-init.d/
# Run file
cp -n /temp/unbound.sh /etc/cont-init.d/unbound
chmod 755 /etc/cont-init.d/unbound
