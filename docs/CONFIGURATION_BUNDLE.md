# Configuration Bundle — dmjl_port (Phase 1: Build & Observe)

This document consolidates all configuration templates, runtime parameters, launch commands, and operational setup notes for every node in the network.

---

## 1. Node 1: Private DNS (`dnsmasq`)

- **Host Machine:** Mac 1 (`10.7.7.61`)
- **Config Template Path:** [`dns/dnsmasq.conf`](../dns/dnsmasq.conf)
- **Deployed Runtime Config:** [`evidence/ev_mac1/dnsmasq.conf`](../evidence/ev_mac1/dnsmasq.conf)
- **Service Port:** `53/UDP` & `53/TCP`

### Deployed Configuration Content
```ini
# Don't read /etc/resolv.conf. Forward non-project domains upstream
no-resolv
server=10.7.0.1
server=8.8.8.8

# Listen on physical Wi-Fi interface and local loopback
interface=en0
listen-address=127.0.0.1,10.7.7.61

# Local A Records for Private Domain
address=/app.dmjl.test/10.7.21.15
address=/api.dmjl.test/10.7.21.15

# Time-To-Live (TTL)
local-ttl=30

# Telemetry and Query Logging
log-queries
log-facility=/tmp/dnsmasq.log
```

### Launch Instructions (Mac 1)
```bash
# Automated launch script
bash dns/start-dns.sh 10.7.21.15

# Or manual procedure:
B=$(brew --prefix)
cp dns/dnsmasq.conf "$B/etc/dnsmasq.conf"
sudo brew services start dnsmasq
sudo networksetup -setdnsservers Wi-Fi 127.0.0.1
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

---

## 2. Node 2: Edge Reverse Proxy & Load Balancer (`nginx`)

- **Host Machine:** Mac 2 (`10.7.21.15`)
- **Config Template Path:** [`nginx/nginx.conf`](../nginx/nginx.conf)
- **Deployed Runtime Config:** [`evidence/ev_mac2/B3_nginx.conf`](../evidence/ev_mac2/B3_nginx.conf)
- **Service Ports:** `443/TCP` (HTTPS / TLS 1.3), `80/TCP` (HTTP Redirect)

### Deployed Configuration Content
```nginx
worker_processes 1;
events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;
    keepalive_timeout 65;

    # Access log tracking upstream target selection
    log_format lb '$remote_addr -> $upstream_addr "$request" $status';
    access_log /opt/homebrew/var/log/nginx/access.log lb;
    error_log  /opt/homebrew/var/log/nginx/error.log;

    # Round-Robin Upstream Target Group with Passive Health Checks
    upstream backend {
        server 10.7.3.17:3001 max_fails=1 fail_timeout=10s;  # Backend Node A
        server 10.3.2.17:3002 max_fails=1 fail_timeout=10s;  # Backend Node B
    }

    # Plain HTTP Server -> Enforces 301 Redirect to HTTPS
    server {
        listen 80;
        server_name app.dmjl.test api.dmjl.test;
        return 301 https://$host$request_uri;
    }

    # HTTPS Edge Server -> TLS 1.3 Termination Point
    server {
        listen 443 ssl;
        server_name app.dmjl.test api.dmjl.test;

        ssl_certificate     /opt/homebrew/etc/nginx/certs/app.dmjl.test.pem;
        ssl_certificate_key /opt/homebrew/etc/nginx/certs/app.dmjl.test-key.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;

        location / {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_connect_timeout 2s;
        }
    }
}
```

### Launch Instructions (Mac 2)
```bash
# Automated launch script
bash nginx/start-nginx.sh

# Or manual procedure:
B=$(brew --prefix)
sed -e "s|__BREW__|$B|g" \
    -e "s|__MAC3_IP__|10.7.3.17|g" \
    -e "s|__MAC4_IP__|10.3.2.17|g" \
    nginx/nginx.conf > "$B/etc/nginx/nginx.conf"
sudo nginx -t && sudo nginx
```

---

## 3. Nodes 3 & 4: Backend REST Applications

- **Backend A Host:** Mac 3 (`10.7.3.17`), Port `3001/TCP`
- **Backend B Host:** Mac 4 (`10.3.2.17`), Port `3002/TCP`
- **Source Code Path:** [`backend/server.py`](../backend/server.py)
- **Language / Runtime:** Python 3 standard library (`http.server`, `json`, `sys`) — zero external dependencies.

### Launch Commands
```bash
# On Mac 3 (Backend A):
python3 backend/server.py A 3001

# On Mac 4 (Backend B):
python3 backend/server.py B 3002
```

### Endpoint Specification
- `GET /`: Returns service identity and status (`{"service": "dmjl_port", "backend": "A", "message": "Backend A is running"}`).
- `GET /api/status`: Returns JSON status object (`{"backend": "A", "status": "ok"}`).
- **Required Response Header:** `X-Backend: A` or `X-Backend: B`.
- **Caching Headers:** `Cache-Control: public, max-age=60`, `ETag: "status-v1"`.
- **Conditional Validation:** If request contains `If-None-Match: "status-v1"`, immediately returns `304 Not Modified` with zero body bytes.

---

## 4. TLS Certificate Setup Notes

- **Authority Architecture:** Custom local Certificate Authority (`dmjl_port Local CA`) generating an X.509 v3 server certificate.
- **Subject Alternative Names (SAN):** `DNS:app.dmjl.test`, `DNS:api.dmjl.test`.
- **CA Config:** [`tls/ca.cnf`](../tls/ca.cnf)
- **Extension Config:** [`tls/server.ext`](../tls/server.ext)
- **Generation Script:** [`tls/make-certs.sh`](../tls/make-certs.sh)
- **Client Trust Script:** [`tls/trust-ca.sh`](../tls/trust-ca.sh)

### Root CA Trust Procedure (Every Client Mac)
To ensure curl and browsers do NOT require the `-k` (insecure) flag:
```bash
# Trust rootCA.pem in macOS System Keychain:
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem

# Append to system OpenSSL bundle for CLI curl:
cat rootCA.pem | sudo tee -a /etc/ssl/cert.pem
```

---

## 5. Client DNS Resolver Configuration

Every client machine (Mac 1, Mac 4, or any test client) points its DNS resolver to Mac 1:
```bash
# Set primary DNS resolver to Mac 1:
sudo networksetup -setdnsservers Wi-Fi 10.7.7.61

# To revert back to automatic DHCP:
sudo networksetup -setdnsservers Wi-Fi empty
```
