#!/bin/bash
set -e

echo "=========================================="
echo "  dmjl_port - Mac 1 Private DNS Server    "
echo "=========================================="

B=$(brew --prefix)
MAC1_IP=$(ipconfig getifaddr en0)
UP=$(ipconfig getoption en0 domain_name_server)
UPSTREAM=${UP:-8.8.8.8}

if [ -z "$MAC1_IP" ]; then
    echo "❌ Error: Could not determine Wi-Fi (en0) IP. Are you connected to Wi-Fi?"
    exit 1
fi

MAC2_IP="$1"
if [ -z "$MAC2_IP" ]; then
    read -p "Enter Jagruthi's IP (Mac 2 Edge) [or press Enter for $MAC1_IP for testing]: " input_ip
    MAC2_IP=${input_ip:-$MAC1_IP}
fi

echo ""
echo "Configuration parameters:"
echo "  • Mac 1 (Your DNS IP) : $MAC1_IP"
echo "  • Mac 2 (Edge IP)     : $MAC2_IP"
echo "  • Upstream DNS        : $UPSTREAM"
echo ""

# Backup original config if not backed up
if [ ! -f "$B/etc/dnsmasq.conf.backup" ]; then
    [ -f "$B/etc/dnsmasq.conf" ] && cp "$B/etc/dnsmasq.conf" "$B/etc/dnsmasq.conf.backup"
fi

# Generate real dnsmasq.conf from template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

sed -e "s/__MAC1_IP__/$MAC1_IP/g" \
    -e "s/__MAC2_IP__/$MAC2_IP/g" \
    -e "s/__UPSTREAM_DNS__/$UPSTREAM/g" \
    "$REPO_DIR/dns/dnsmasq.conf" > "$B/etc/dnsmasq.conf"

echo "Checking dnsmasq configuration syntax..."
$B/sbin/dnsmasq --test -C "$B/etc/dnsmasq.conf"

echo ""
echo "Starting dnsmasq service (requires admin password)..."
sudo brew services restart dnsmasq || sudo brew services start dnsmasq

echo "Pointing Mac 1 DNS to local dnsmasq (127.0.0.1)..."
sudo networksetup -setdnsservers Wi-Fi 127.0.0.1

echo "Flushing macOS DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo ""
echo "=========================================="
echo "  Testing DNS Resolution                  "
echo "=========================================="
echo "1. Resolving app.dmjl.test via 127.0.0.1:"
dig @127.0.0.1 app.dmjl.test +short
echo ""
echo "2. Resolving app.dmjl.test via $MAC1_IP:"
dig @$MAC1_IP app.dmjl.test +short
echo ""
echo "3. Resolving google.com (upstream test):"
dig google.com +short | head -1
echo ""

# Save evidence
mkdir -p ~/Desktop/ev_mac1
grep -v '^#' "$B/etc/dnsmasq.conf" | grep -v '^$' | tee ~/Desktop/ev_mac1/A2_dnsmasq.txt
cp "$B/etc/dnsmasq.conf" ~/Desktop/ev_mac1/dnsmasq.conf
[ -f /tmp/dnsmasq.log ] && sudo chmod 644 /tmp/dnsmasq.log 2>/dev/null || true

echo ""
echo "✅ DNS Server is ACTIVE and resolving!"
echo "📁 Evidence saved to ~/Desktop/ev_mac1/A2_dnsmasq.txt"
echo "To revert DNS back to normal when done, run: ./dns/stop-dns.sh"
