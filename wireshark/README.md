# Wireshark Deep Packet Inspection (DPI) & Protocol Traces

> **Capture Node:** Mac 3 (`10.7.3.17`)  
> **Interface:** `en0` (Physical Wi-Fi LAN)  
> **Trace File:** [`dmjl_phase1_capture.pcapng`](dmjl_phase1_capture.pcapng)  
> **Capture Lead:** Chaitanya Sai Meka ([@ChaitanyaSai-Meka](https://github.com/ChaitanyaSai-Meka))  

---

## 📑 Packet Capture Inventory

| Artifact | Wireshark Display Filter | Protocol Layer | Description |
|---|---|---|---|
| [`C1_dns.png`](C1_dns.png) | `dns.qry.name == "app.dmjl.test"` | Application (UDP 53) | Private DNS query and A-record answer (AA flag set) pointing to `10.7.21.15`. |
| [`C2_tcp.png`](C2_tcp.png) | `ip.addr == 10.7.21.15 && tcp.port == 443` | Transport (TCP 443) | Standard 3-way handshake (`[SYN]`, `[SYN, ACK]`, `[ACK]`) before TLS negotiation. |
| [`C3_tls.png`](C3_tls.png) | `ip.addr == 10.7.21.15 && tls` | Presentation (TLS 1.3) | Client Hello cipher suites and Server Hello handshake establishment. |
| [`C3_cert.png`](C3_cert.png) | `tls.handshake.type == 11` | Security (X.509) | Server certificate payload presenting `CN=app.dmjl.test` issued by local CA. |
| [`C3_tls_v2.png`](C3_tls_v2.png) + [`dmjl_phase1_capture_v2_trusted.pcapng`](dmjl_phase1_capture_v2_trusted.pcapng) | `tls` | Presentation (TLS 1.3) | Re-capture after Mac 3 trusted the local CA (edge at `10.7.25.241` via DHCP): full handshake, encrypted request/response, no TLS alerts. |
| [`C_bonus_http.png`](C_bonus_http.png) | `http && tcp.port == 3001` | Application (HTTP/1.0) | **🌟 BONUS PROOF:** Unencrypted HTTP traffic from Edge to Backend, proving TLS termination. |

---

## 📸 Visual Inspection Gallery

### 1. DNS Query & Response (`C1_dns.png`)
- **Query (Frame 134):** Client `10.7.3.17:59955` sends UDP query for `app.dmjl.test` to private resolver `10.7.7.61:53` (Transaction ID `0x205c`).
- **Answer (Frame 141):** Resolver returns `10.7.21.15` with TTL 30s (`Flags: 0x8580` Standard query response, Authoritative Answer, No error).
![C1 DNS Query and Response](C1_dns.png)

---

### 2. TCP 3-Way Handshake (`C2_tcp.png`)
- **SYN (Frame 143):** Client (`10.7.3.17:62924`) sends `[SYN]` to Edge (`10.7.21.15:443`) with Seq=0.
- **SYN-ACK (Frame 146):** Edge responds with `[SYN, ACK]` (Seq=0, Ack=1).
- **ACK (Frame 147):** Client confirms with `[ACK]` (Seq=1, Ack=1).
- **Outcome:** Reliable, ordered, connection-oriented channel established before any application data is sent.
![C2 TCP 3-Way Handshake](C2_tcp.png)

---

### 3. TLS Handshake & Cipher Negotiation (`C3_tls.png`)
- **Client Hello (Frame 148):** Client offers `supported_versions` TLS 1.3/1.2/1.1/1.0, SNI (`app.dmjl.test`), and 49 cipher suites (incl. `0x00ff` SCSV).
- **Server Hello (Frame 151):** Edge selects `TLS_CHACHA20_POLY1305_SHA256` (`0x1303`) under TLS 1.3. The same segment carries ChangeCipherSpec (middlebox compatibility, RFC 8446) and four encrypted records of 70, 832, 281 and 53 bytes: EncryptedExtensions, Certificate, CertificateVerify and Finished. Each is the plaintext size seen in `curl -v` (53, 815, 264, 36 bytes) plus 17 bytes of AEAD overhead, so in TLS 1.3 the certificate itself is encrypted.
- **Confidentiality:** In TLS 1.3, all subsequent handshake records and application payload (HTTP GET, headers, JSON body) are encapsulated in encrypted Application Data records (content type 23).
![C3 TLS Handshake](C3_tls.png)

---

### 4. TLS Certificate Payload (`C3_cert.png`)
- **Certificate Inspection (Frame 193):** Under a TLS 1.2 negotiation (`tls.handshake.type == 11`), the server delivers the cleartext X.509 certificate payload presenting `CN=app.dmjl.test` and signed by `CN=dmjl_port Local CA`.
![C3 Certificate Inspection](C3_cert.png)

---

### 5. Trusted Re-capture (`dmjl_phase1_capture_v2_trusted.pcapng`, `C3_tls_v2.png`)
Extra capture taken on Mac 3 on 5 October 2026, after Mac 3 trusted `dmjl_port Local CA` (`tls/trust-ca.sh`). Campus Wi-Fi assigns IPs by DHCP, so the edge (Mac 2) is at `10.7.25.241` in this capture instead of `10.7.21.15`; Mac 1 (`10.7.7.61`) and Mac 3 (`10.7.3.17`) are unchanged. Roles and configuration are the same.

One `curl https://app.dmjl.test/api/status` from Mac 3, end to end:
- **DNS (Frames 465 → 473):** `10.7.3.17:61541` → `10.7.7.61:53`, ID `0xf4a6`; answer `10.7.25.241`, TTL 30, flags `0x8580`.
- **TCP (Frames 474 → 475 → 476):** `10.7.3.17:63469` ↔ `10.7.25.241:443` — SYN, SYN-ACK, ACK (`tcp.stream eq 3`).
- **TLS 1.3 (Frames 477 → 493):** ClientHello (SNI `app.dmjl.test`) → ServerHello `TLS_CHACHA20_POLY1305_SHA256` + encrypted EncryptedExtensions/Certificate/CertificateVerify/Finished.
- **Handshake completes (Frames 495–497):** client ChangeCipherSpec, encrypted Finished, then the encrypted HTTP request (Application Data).
- **Encrypted response (Frame 764):** Application Data from the edge carrying the HTTP response; `tls.alert_message` returns **no packets** — the certificate was accepted.
- **TLS termination (Frames 753–760):** nginx (`10.7.25.241`) opens a new TCP connection to Backend A `10.7.3.17:3001` and sends **plaintext** `GET /api/status HTTP/1.1` with `X-Real-IP`/`X-Forwarded-For: 10.7.3.17` and `X-Forwarded-Proto: https`; Backend A answers `HTTP/1.0 200 OK`, `X-Backend: A`, `{"backend": "A", "status": "ok"}`.
- **Upstream failover:** ~2 s pass between the client's request (Frame 497, t=3.498 s) and nginx's SYN to Backend A (Frame 753, t=5.536 s). Backend B was not running during this capture, so nginx waited `proxy_connect_timeout 2s` on B, then retried on A — the client still got its response.

![C3 v2 Trusted TLS Handshake](C3_tls_v2.png)

---

### 6. 🌟 Bonus Trace: Reverse Proxy TLS Offloading (`C_bonus_http.png`)
- **Architecture Validation:** Demonstrates that while client-to-edge traffic is encrypted with TLS 1.3 on port 443, traffic between Nginx (`10.7.21.15`) and Backend A (`10.7.3.17:3001`) is clean, unencrypted HTTP GET traffic.
- **Source:** This screenshot comes from a separate capture; `dmjl_phase1_capture.pcapng` contains no plaintext HTTP.
- **Proof:** Confirms that TLS terminates strictly at the edge proxy, exactly mirroring enterprise cloud architecture (e.g. AWS ALB to EC2).
![Bonus Cleartext HTTP Trace](C_bonus_http.png)
