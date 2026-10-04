#!/bin/bash
set -e

echo "=========================================="
echo "  dmjl_port - Mac 2 Edge (nginx + TLS)    "
echo "=========================================="

B=$(brew --prefix)

# Check IPs
MAC3_IP=${MAC3_IP:-10.7.3.17}
MAC4_IP=${MAC4_IP:-10.3.2.17}

echo "Using Backend IPs:"
echo "  • Backend A (Meka, Mac 3) : $MAC3_IP:3001"
echo "  • Backend B (Lalith, Mac 4): $MAC4_IP:3002"
echo ""

# Stop existing nginx if any
brew services stop nginx 2>/dev/null || true
sudo nginx -s stop 2>/dev/null || true

# Prepare certificate directory
mkdir -p "$B/etc/nginx/certs" "$B/var/log/nginx"

if [ ! -f ~/dmjl-certs/app.dmjl.test.pem ]; then
    echo "Creating certificates first..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/../tls/make-certs.sh"
fi

cp ~/dmjl-certs/app.dmjl.test.pem "$B/etc/nginx/certs/"
cp ~/dmjl-certs/app.dmjl.test-key.pem "$B/etc/nginx/certs/"

# Backup default nginx.conf
[ -f "$B/etc/nginx/nginx.conf.backup" ] || cp "$B/etc/nginx/nginx.conf" "$B/etc/nginx/nginx.conf.backup" 2>/dev/null || true

# Substitute template
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

sed -e "s|__BREW__|$B|g" \
    -e "s|__MAC3_IP__|$MAC3_IP|g" \
    -e "s|__MAC4_IP__|$MAC4_IP|g" \
    "$REPO_DIR/nginx/nginx.conf" > "$B/etc/nginx/nginx.conf"

echo "Testing nginx syntax..."
sudo nginx -t

echo ""
echo "Starting nginx on port 443..."
sudo nginx

echo "Testing connectivity to backends:"
curl -s "http://$MAC3_IP:3001/api/status" && echo ""
curl -s "http://$MAC4_IP:3002/api/status" && echo ""

echo ""
echo "Verifying nginx listening on port 443:"
sudo lsof -nP -iTCP:443 -sTCP:LISTEN

echo ""
echo "✅ Edge nginx is RUNNING on Mac 2!"
