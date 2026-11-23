#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
EVIDENCE_DIR="$REPO_DIR/evidence/phase2/mac1-dhanvin"
CONFIG="$EVIDENCE_DIR/primary-dns.conf"
LOG="$EVIDENCE_DIR/05-primary-dns-runtime.txt"
DNSMASQ_BIN="$(brew --prefix)/sbin/dnsmasq"

echo "Testing Phase 2 primary DNS configuration..."
"$DNSMASQ_BIN" --test --conf-file="$CONFIG"

echo
echo "Starting primary DNS on 10.239.23.157:53."
echo "macOS will ask for Dhanvin's administrator password."
echo "Keep this window open during Phase 2 testing."
echo

sudo "$DNSMASQ_BIN" \
  --keep-in-foreground \
  --log-facility=- \
  --conf-file="$CONFIG" 2>&1 | tee "$LOG"
