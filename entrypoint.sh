#!/bin/bash

# Start Unbound in the background
unbound -d -c /etc/unbound/unbound.conf &

# Start Stubby in the background
stubby -C /etc/stubby/stubby.yml &

# Start Cloudflared in the background
cloudflared --config /etc/cloudflared/config.yml run &

# Start AdGuard Home - skal denne med? -w /opt/adguardhome/work
/opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml
