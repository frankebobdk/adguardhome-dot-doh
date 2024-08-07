#!/bin/sh

# Start Unbound
unbound -d -c /etc/unbound/unbound.conf &

# Start Stubby
stubby -C /usr/local/etc/stubby/stubby.yml &

# Start cloudflared
cloudflared tunnel --config /opt/cloudflared/config.yml run &

# Start AdGuardHome
/opt/adguardhome/AdGuardHome -h 0.0.0.0 -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work
