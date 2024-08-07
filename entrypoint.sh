#!/bin/bash

# Start Cloudflared in the background
cloudflared tunnel --url http://localhost:3000 &

# Start AdGuard Home
/opt/adguardhome/AdGuardHome -c /opt/adguardhome/conf/AdGuardHome.yaml
