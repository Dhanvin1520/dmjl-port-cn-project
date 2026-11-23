#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RESOLVER_FILE=/etc/resolver/dmjl.test
BACKUP_FILE="$REPO_DIR/evidence/phase2/mac1-dhanvin/dmjl.test.resolver.before"

echo "This installs the project CA and configures scoped dmjl.test DNS."
echo "macOS will ask for Dhanvin's administrator password."

if [ -f "$RESOLVER_FILE" ] && [ ! -f "$BACKUP_FILE" ]; then
    cp "$RESOLVER_FILE" "$BACKUP_FILE"
fi

bash "$REPO_DIR/tls/trust-ca.sh"

sudo mkdir -p /etc/resolver
printf 'nameserver 10.239.23.157\nnameserver 10.239.23.49\n' \
  | sudo tee "$RESOLVER_FILE" >/dev/null

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

echo
echo "Configured $RESOLVER_FILE:"
cat "$RESOLVER_FILE"
echo
echo "Testing ordinary client resolution:"
dscacheutil -q host -a name app.dmjl.test
echo
echo "Testing trusted HTTPS without --cacert or -k:"
curl -sS -D - -o /dev/null https://app.dmjl.test/api/status
