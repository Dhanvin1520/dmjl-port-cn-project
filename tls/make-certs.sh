#!/bin/bash
# Creates our local CA + a server certificate for app.dmjl.test
# Output folder: ~/dmjl-certs  (private keys never go into the repo)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HOME/dmjl-certs"
mkdir -p "$OUT"
cd "$OUT"
if [ -f rootCA.pem ]; then
  echo "Certificates already exist in $OUT - not regenerating."
else
  openssl genrsa -out rootCA.key 2048
  openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 365 \
    -config "$HERE/ca.cnf" -out rootCA.pem
  openssl genrsa -out app.dmjl.test-key.pem 2048
  openssl req -new -key app.dmjl.test-key.pem \
    -subj "/CN=app.dmjl.test" -out app.csr
  openssl x509 -req -in app.csr -CA rootCA.pem -CAkey rootCA.key \
    -CAcreateserial -out app.dmjl.test.pem -days 365 -sha256 \
    -extfile "$HERE/server.ext"
fi
openssl verify -CAfile rootCA.pem app.dmjl.test.pem
