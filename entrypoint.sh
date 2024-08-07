#!/bin/bash

# Start Unbound in the background - fjernet "-d"
unbound -v -c /etc/unbound/unbound.conf &

# Start Stubby in the background
stubby -C /etc/stubby/stubby.yml &

# Start Cloudflared in the background
cloudflared --config /etc/cloudflared/config.yml run &

# Start AdGuard Home
/opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work
