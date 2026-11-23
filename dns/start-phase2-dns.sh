#!/bin/bash
set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 SELF_ZT_IP EDGE_ZT_IP ZT_INTERFACE [PORT]" >&2
    echo "Example: sudo $0 10.239.23.157 10.239.23.49 feth2917" >&2
    exit 2
fi

SELF_ZT_IP=$1
EDGE_ZT_IP=$2
ZT_INTERFACE=$3
DNS_PORT=${4:-53}
DNS_CONFIG_PATH=${DNS_CONFIG_PATH:-/tmp/dmjl-phase2-dnsmasq.conf}

case "$SELF_ZT_IP:$EDGE_ZT_IP" in
    *[!0-9.:]*) echo "Both addresses must be literal IPv4 addresses." >&2; exit 2 ;;
esac

if ! ifconfig "$ZT_INTERFACE" 2>/dev/null | grep -q "inet $SELF_ZT_IP "; then
    echo "$ZT_INTERFACE does not own $SELF_ZT_IP on this Mac." >&2
    exit 1
fi

DNSMASQ_BIN="$(brew --prefix)/sbin/dnsmasq"

mkdir -p "$(dirname "$DNS_CONFIG_PATH")"
cat > "$DNS_CONFIG_PATH" <<EOF
port=$DNS_PORT
interface=$ZT_INTERFACE
listen-address=$SELF_ZT_IP
bind-interfaces
no-resolv
local=/dmjl.test/
address=/app.dmjl.test/$EDGE_ZT_IP
address=/api.dmjl.test/$EDGE_ZT_IP
local-ttl=30
log-queries
EOF

"$DNSMASQ_BIN" --test --conf-file="$DNS_CONFIG_PATH"
echo "Starting Phase 2 DNS on $SELF_ZT_IP:$DNS_PORT via $ZT_INTERFACE"
echo "app.dmjl.test and api.dmjl.test -> $EDGE_ZT_IP (TTL 30)"
exec "$DNSMASQ_BIN" --keep-in-foreground --log-facility=- --conf-file="$DNS_CONFIG_PATH"
