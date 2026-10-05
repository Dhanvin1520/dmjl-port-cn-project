# Phase 1 Final Report — dmjl_port (Section C, Type 1)

One-document summary of the whole Phase 1 build: what we built, how a request travels through it, every Wireshark capture explained frame by frame, and every failure we demonstrated. All numbers below come from the files in this repository.

---

## 1. Summary

A client types `https://app.dmjl.test`. Our private DNS server (Mac 1) resolves the name to our nginx edge (Mac 2). The client opens a TCP connection to port 443, completes a TLS 1.3 handshake with nginx, and sends its HTTP request inside the encrypted channel. nginx terminates TLS and forwards the request as plain HTTP to Backend A (Mac 3) or Backend B (Mac 4) in round-robin order. Each backend answers with JSON and an `X-Backend` header, so every response shows which server handled it.

| Requirement (Phase 1 gate) | Result |
|---|---|
| Client resolves `app.dmjl.test` through our own DNS | ✅ `dig` SERVER = `10.7.7.61` (Mac 1), answer = edge IP |
| Name is private | ✅ `dig @8.8.8.8` → `NXDOMAIN` |
| HTTPS by name, certificate trusted, no `-k` | ✅ `SSL certificate verify ok`, HTTP 200 |
| Responses from both backends through the load balancer | ✅ `X-Backend` alternates A, B, A, B, A, B |
| Caching demonstrated | ✅ `Cache-Control: public, max-age=60` + `ETag`, conditional request → `304 Not Modified` |
| Full DNS → TCP → TLS → HTTP flow captured | ✅ Two Wireshark captures (Section 5) |
| All five failure scenarios demonstrated | ✅ Section 7 |

---

## 2. Team and roles

| Machine | Person | Role | Service and port | Cloud equivalent |
|---|---|---|---|---|
| Mac 1 | Dhanvin Vadlamudi | Private DNS server | `dnsmasq`, UDP/TCP 53 | AWS Route 53 private hosted zone |
| Mac 2 | Jagruthi Pulumati | Edge reverse proxy, TLS termination, load balancer | `nginx`, TCP 80 (redirect) and 443 | AWS Application Load Balancer |
| Mac 3 | Chaitanya Sai Meka | Backend A, Wireshark captures | Python REST, TCP 3001 | EC2 target A |
| Mac 4 | Kasula Lalithendra | Backend B, test client | Python REST, TCP 3002 + `curl`/`dig` | EC2 target B + client |

---

## 3. Network inventory

### 3.1 Evidence session — 4 October 2026

All four Macs on the campus Wi-Fi, interface `en0`.

| Machine | IPv4 | Mask | Gateway | MAC address |
|---|---|---|---|---|
| Mac 1 | `10.7.7.61` | `255.255.224.0` (/19) | `10.7.0.1` | `e6:b8:3b:28:6c:20` |
| Mac 2 | `10.7.21.15` | `255.255.224.0` (/19) | `10.7.0.1` | `9a:d6:ee:1f:bc:04` |
| Mac 3 | `10.7.3.17` | `255.255.224.0` (/19) | `10.7.0.1` | `36:0e:62:54:af:03` |
| Mac 4 | `10.3.2.17` | `255.255.252.0` (/22) | `10.3.0.1` | `0a:d0:f3:54:d8:38` |

Macs 1–3 share `10.7.0.0/19`. Mac 4 is on `10.3.0.0/22` and is reached through one campus router hop, which is why pings to Mac 4 show TTL 63 and pings inside `10.7.0.0/19` show TTL 64. All six machine pairs pinged with 0% loss (`evidence/ev_mac*/A5_pings_*.txt`).

### 3.2 Re-capture and live demo — 5 October 2026

Campus Wi-Fi assigns addresses by DHCP. On 5 October Mac 2 received **`10.7.25.241`**; Mac 1 (`10.7.7.61`) and Mac 3 (`10.7.3.17`) kept their addresses. We updated the DNS record with `dns/start-dns.sh 10.7.25.241` — nothing else changed. The trusted re-capture (Section 5.2) and the live demo video use these addresses.

---

## 4. How one request travels (layer by layer)

| Step | Layer | Protocol | From → To | What happens |
|---|---|---|---|---|
| 1 | Application | DNS over UDP | client:ephemeral → Mac 1:53 | "Where is app.dmjl.test?" → edge IP, TTL 30 s |
| 2 | Transport | TCP | client:ephemeral → Mac 2:443 | SYN, SYN-ACK, ACK — reliable byte stream opened |
| 3 | Session/Presentation | TLS 1.3 | client ↔ Mac 2:443 | ClientHello (SNI) → ServerHello → encrypted certificate → Finished; keys from ECDHE |
| 4 | Application | HTTP/1.1 inside TLS | client → Mac 2 | `GET /api/status` travels encrypted |
| 5 | Application | HTTP (plaintext) | Mac 2 → Mac 3:3001 or Mac 4:3002 | nginx terminates TLS and proxies in round-robin order |
| 6 | Application | HTTP response | backend → Mac 2 → client | JSON + `X-Backend`, re-encrypted by nginx for the client |

Below these sit IPv4 (network layer, private `10.x` addresses) and Wi-Fi/Ethernet frames (link layer, MAC addresses in Section 3.1).

**DNS vs connection:** DNS only finds the IP address. The TCP and TLS connection that follows is a separate step to a different machine (Mac 2), which is why DNS can work while the service is down and vice versa (Section 7).

---

## 5. Wireshark analysis

Both captures were taken on Mac 3 (`en0`) while Mac 3 ran `curl https://app.dmjl.test/...`.

| | Capture 1 | Capture 2 (trusted re-capture) |
|---|---|---|
| File | `wireshark/dmjl_phase1_capture.pcapng` | `wireshark/dmjl_phase1_capture_v2_trusted.pcapng` |
| Date | 4 October 2026 | 5 October 2026 |
| Edge (Mac 2) IP | `10.7.21.15` | `10.7.25.241` |
| Packets | 403 | 893 |
| Screenshots | `C1_dns.png`, `C2_tcp.png`, `C3_tls.png`, `C3_cert.png` | `C3_tls_v2.png` |

### 5.1 Capture 1 — 4 October

**DNS** (filter `dns`, screenshot `C1_dns.png`)

| Frame | Time | Source → Destination | Details |
|---|---|---|---|
| 134 | 6.401 s | `10.7.3.17:59955` → `10.7.7.61:53` (UDP) | Standard query `0x205c`, A `app.dmjl.test`, flags `0x0100` (recursion desired) |
| 141 | 6.412 s | `10.7.7.61:53` → `10.7.3.17:59955` (UDP) | Response `0x205c`, flags `0x8580` (AA, RD, RA, no error), **A `10.7.21.15`, TTL 30** |

DNS round trip: 11.3 ms. Port 59955 is an ephemeral client port (macOS range 49152–65535); 53 is the well-known DNS port. The AA flag shows dnsmasq answered from its own records.

**TCP 3-way handshake** (filter `tcp.flags.syn==1`, then `tcp.stream eq 3`, screenshot `C2_tcp.png`)

| Frame | Time | Direction | Flags | Seq / Ack |
|---|---|---|---|---|
| 143 | 6.4150 s | `10.7.3.17:62924` → `10.7.21.15:443` | `0x0c2` SYN, ECE, CWR | Seq 0 (raw 616026887) |
| 146 | 6.4250 s | `10.7.21.15:443` → `10.7.3.17:62924` | `0x052` SYN, ACK, ECE | Seq 0 (raw 3892098533), Ack 1 (raw 616026888) |
| 147 | 6.4252 s | `10.7.3.17:62924` → `10.7.21.15:443` | `0x010` ACK | Seq 1, Ack 1 |

Handshake round trip: 10.0 ms. Each side's Initial Sequence Number is exchanged and acknowledged (raw Ack = peer's raw Seq + 1). ECE/CWR in the SYN is ECN negotiation. The ClientHello (frame 148) comes only after the ACK — TCP is established before any TLS data.

**TLS 1.3 handshake** (filter `tls`, screenshot `C3_tls.png`)

| Frame | Time | Content |
|---|---|---|
| 148 | 6.427 s | **ClientHello** — record version TLS 1.0 (legacy field), `supported_versions` = TLS 1.3, 1.2, 1.1, 1.0; SNI `app.dmjl.test`; 49 cipher suites, first three `0x1303` CHACHA20-POLY1305, `0x1302` AES-256-GCM, `0x1301` AES-128-GCM |
| 151 | 6.439 s | **ServerHello** — TLS 1.3, `TLS_CHACHA20_POLY1305_SHA256` (`0x1303`); plus ChangeCipherSpec (middlebox compatibility only, RFC 8446) and four encrypted records of 70, 832, 281 and 53 bytes |

Those four encrypted records are EncryptedExtensions, Certificate, CertificateVerify and Finished. Their sizes equal the plaintext sizes reported by `curl -v` (53, 815, 264, 36 bytes) plus 17 bytes of AEAD overhead each (16-byte tag + 1-byte inner content type) — so in TLS 1.3 the certificate itself is encrypted on the wire.

**Certificate in plaintext** (filter `tls.handshake.type == 11`, screenshot `C3_cert.png`)

| Frame | Content |
|---|---|
| 193 | TLS 1.2 handshake (`tcp.stream eq 5`), where the Certificate message is sent unencrypted: subject `CN=app.dmjl.test`, issuer `CN=dmjl_port Local CA` |

### 5.2 Capture 2 — trusted re-capture, 5 October

Taken after Mac 3 trusted our root CA (`tls/trust-ca.sh`). One `curl https://app.dmjl.test/api/status`, captured end to end — DNS, TCP, TLS, the encrypted request and response, and nginx's plaintext hop to the backend.

| Frames | Time | Step | Details |
|---|---|---|---|
| 465 → 473 | 3.382 → 3.412 s | DNS | `10.7.3.17:61541` → `10.7.7.61:53`, ID `0xf4a6`; answer **`10.7.25.241`**, TTL 30, flags `0x8580` (30.6 ms) |
| 474 → 475 → 476 | 3.416 → 3.437 s | TCP | `10.7.3.17:63469` ↔ `10.7.25.241:443`: SYN `0x0c2`, SYN-ACK `0x052`, ACK `0x010` (20.8 ms) |
| 477 | 3.438 s | ClientHello | SNI `app.dmjl.test`, same 49 cipher suites, TLS 1.3 offered |
| 493 | 3.496 s | ServerHello | TLS 1.3, `0x1303`; ChangeCipherSpec + encrypted EncryptedExtensions, Certificate (832 B), CertificateVerify, Finished |
| 495 → 496 | 3.498 s | Handshake completes | client ChangeCipherSpec, encrypted client Finished |
| 497 | 3.498 s | **Encrypted HTTP request** | Application Data, 103-byte record (`GET /api/status`) |
| 499, 500 | 3.522 s | Server records | two encrypted 282-byte records from the server (TLS 1.3 NewSessionTicket messages, by size and timing) |
| 753 → 754 | 5.536 s | nginx → Backend A | new TCP connection `10.7.25.241:56078` → `10.7.3.17:3001` |
| 755 | 5.544 s | **Plaintext proxied request** | `GET /api/status HTTP/1.1` with `X-Real-IP: 10.7.3.17`, `X-Forwarded-For: 10.7.3.17`, `X-Forwarded-Proto: https` |
| 759 → 760 | 5.560 s | **Plaintext backend response** | `HTTP/1.0 200 OK`, `X-Backend: A`, `Cache-Control: public, max-age=60`, `ETag: "status-v1"`, body `{"backend": "A", "status": "ok"}` |
| 764 | 5.580 s | **Encrypted HTTP response** | Application Data, 271-byte record, edge → client |
| 767 | 5.581 s | Close | client's encrypted close record |

What this capture proves:
- **The handshake completes and the certificate is accepted** — the filter `tls.alert_message` returns no packets.
- **TLS terminates at nginx.** Between client and edge (port 443) the HTTP request and response are only Application Data. Between nginx and Backend A (port 3001) the same request is readable plaintext, with the client's real IP passed in `X-Real-IP` / `X-Forwarded-For`.
- **Upstream failover in packets.** About 2 s pass between the encrypted request (frame 497, 3.498 s) and nginx's SYN to Backend A (frame 753, 5.536 s). Backend B was not running during this capture, so nginx waited its `proxy_connect_timeout 2s` on B, then retried the same request on A. The client still got its response.

### 5.3 Ports and socket pairs

| Hop | Client side (ephemeral) | Server side (well-known / fixed) | Transport |
|---|---|---|---|
| DNS, capture 1 | `10.7.3.17:59955` | `10.7.7.61:53` | UDP |
| HTTPS, capture 1 | `10.7.3.17:62924` | `10.7.21.15:443` | TCP |
| DNS, capture 2 | `10.7.3.17:61541` | `10.7.7.61:53` | UDP |
| HTTPS, capture 2 | `10.7.3.17:63469` | `10.7.25.241:443` | TCP |
| nginx → Backend A, capture 2 | `10.7.25.241:56078` | `10.7.3.17:3001` | TCP |

### 5.4 Why Wireshark cannot read the HTTP headers

After ServerHello, every TLS 1.3 record is encrypted with symmetric session keys derived from an ephemeral (EC)DHE key exchange. The request line, headers and JSON body travel inside Application Data records (content type 23), so Wireshark sees only record lengths and ciphertext. It would need the session secrets (an `SSLKEYLOGFILE`) to decrypt them — and because the keys are ephemeral, even the server's private key would not be enough. Only nginx on Mac 2, where TLS terminates, sees the plaintext — which capture 2 confirms on the nginx → backend hop.

---

## 6. HTTPS, load balancing and caching

**HTTPS** (`evidence/ev_mac4/B1_curl_v.txt`, from Mac 4, no `-k`): TLS 1.3 with `AEAD-CHACHA20-POLY1305-SHA256`, subject `CN=app.dmjl.test`, SAN matched, issuer `CN=dmjl_port Local CA`, `SSL certificate verify ok`, `HTTP/1.1 200 OK`. Clients trust the CA through `tls/trust-ca.sh` (macOS Keychain + `/etc/ssl/cert.pem`).

**Load balancing** (`B2_lb_6x.txt`): six requests → `X-Backend` A, B, A, B, A, B. nginx's upstream uses the default round-robin with `max_fails=1 fail_timeout=10s`. Clients only ever know the edge's address; backend IPs stay internal.

**Caching** (`D1_headers.txt`, `D1_304.txt`):
- `Cache-Control: public, max-age=60` — for 60 s a cache may reuse the response with no network traffic (fresh hit).
- After 60 s the copy is stale; the client revalidates with `If-None-Match: "status-v1"`.
- Unchanged resource → `304 Not Modified`, no body; the cached copy is reused.
- First visit or changed ETag → full `200 OK` with body and new ETag.

---

## 7. Failure demonstrations (Section 6.3)

| # | Scenario | What we saw | Layer it shows | Evidence |
|---|---|---|---|---|
| F1 | Client asks the wrong DNS server (8.8.8.8) | `NXDOMAIN`; `curl` cannot resolve the host; ping to the edge IP still works | DNS and IP are independent | `evidence/failures/F1_wrong_dns_server.txt` |
| F2 | DNS record points to the wrong IP (Mac 3) | Name resolves to `10.7.3.17`; `curl` gets `Connection refused` on 443 | DNS is a directory, not a connection | `F2_wrong_dns_record.txt` |
| F3 | One backend stopped | All requests answered by B, no errors | nginx failover at the edge | `F3_one_backend_down.txt`, D3 below |
| F4 | Both backends stopped | TLS still succeeds (`verify ok`), nginx returns `502 Bad Gateway` | Where the edge ends and the backend begins | `F4_both_backends_down.txt` |
| F5 | Wrong destination port (9999) | Ping to the edge works; port 9999 `Connection refused` | IP address and port are separate identifiers | `F5_wrong_port.txt` |
| — | Restored | A, B, A, B, A, B again | — | `F_restored.txt` |

**D3 in detail — Option A, Backend A stopped** (`evidence/ev_mac4/D3_*.txt`, run from Mac 4):
1. **Before:** A, B, A, B, A, B.
2. **Action:** `Ctrl+C` on `python3 backend/server.py A 3001` on Mac 3.
3. **Lower layers still fine:** `dig` → `NOERROR`, `10.7.21.15`, SERVER `10.7.7.61`; the edge answers ping (3/3, TTL 63).
4. **After:** six requests, all `200 OK` from B.
5. **Why:** nothing listens on `10.7.3.17:3001`, so nginx's TCP connect is refused (RST). With `max_fails=1 fail_timeout=10s` and the default `proxy_next_upstream error timeout`, nginx marks A as failed and resends the same request to B — the client never sees an error.
6. **Restored:** A restarted; requests 1–2 still went to B (A's 10 s `fail_timeout` had not expired), then A, B alternation resumed.

**Diagnosis order we use:** name resolution (`dig`) → reachability (`ping`) → port (`nc -zv`) → TLS (`curl -v`) → application (`curl -si`, `X-Backend`).

---

## 8. Running it

Full commands in [`docs/CONFIGURATION_BUNDLE.md`](CONFIGURATION_BUNDLE.md).

| Mac | Command |
|---|---|
| Mac 1 | `bash dns/start-dns.sh <Mac 2 IP>` |
| Mac 2 | `MAC3_IP=<Mac 3 IP> MAC4_IP=<Mac 4 IP> bash nginx/start-nginx.sh` |
| Mac 3 | `python3 backend/server.py A 3001` |
| Mac 4 | `python3 backend/server.py B 3002` |
| Every client | `bash tls/trust-ca.sh`, and DNS server set to Mac 1 |

If DHCP changes an address: re-run `start-dns.sh` when Mac 2 changes, `start-nginx.sh` when Mac 3 or Mac 4 changes, and update client DNS settings when Mac 1 changes.

---

## 9. Where everything is

| Deliverable | Location |
|---|---|
| Architecture (topology, IP table, request flow) | [`ARCHITECTURE.md`](../ARCHITECTURE.md) |
| Configuration bundle | [`docs/CONFIGURATION_BUNDLE.md`](CONFIGURATION_BUNDLE.md), `dns/`, `nginx/`, `tls/` |
| Backend source | [`backend/server.py`](../backend/server.py) |
| Terminal evidence (A1–D3) | [`evidence/`](../evidence/README.md) |
| Failure evidence (F1–F5) | [`evidence/failures/`](../evidence/failures/) |
| Wireshark captures and screenshots | [`wireshark/`](../wireshark/README.md) |
| Failure analysis | [`docs/FAILURE_ANALYSIS.md`](FAILURE_ANALYSIS.md) |
| Course topic mapping | [`docs/COURSE_TOPIC_MAPPING.md`](COURSE_TOPIC_MAPPING.md) |
