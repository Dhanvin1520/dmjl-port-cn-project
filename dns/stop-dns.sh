#!/bin/bash
echo "Stopping dnsmasq service..."
sudo brew services stop dnsmasq 2>/dev/null || true

echo "Restoring Wi-Fi DNS to automatic (DHCP)..."
sudo networksetup -setdnsservers Wi-Fi empty

echo "Flushing macOS DNS cache..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo "✅ DNS restored to default settings!"
