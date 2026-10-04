#!/bin/bash
set -e

CA="$HOME/Downloads/rootCA.pem"
[ -f "$CA" ] || CA="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/rootCA.pem"

if [ ! -f "$CA" ]; then
    echo "❌ Error: rootCA.pem not found!"
    exit 1
fi

echo "Found CA at: $CA"
echo "1. Adding rootCA.pem to macOS System Keychain (trustRoot)..."
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA"

echo "2. Adding rootCA.pem to /etc/ssl/cert.pem for Terminal curl..."
[ -f /etc/ssl/cert.pem.backup ] || sudo cp /etc/ssl/cert.pem /etc/ssl/cert.pem.backup
cat "$CA" | sudo tee -a /etc/ssl/cert.pem > /dev/null

echo ""
echo "3. Testing connection to https://app.dmjl.test/api/status without -k flag:"
curl -s https://app.dmjl.test/api/status || echo "(Note: If connection refused, Jagruthi needs to start nginx)"
echo ""
echo "✅ Certificate trusted successfully!"
