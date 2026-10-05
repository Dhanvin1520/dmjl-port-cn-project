# Course Topic Mapping & Theoretical Alignment — Phase 1

This document maps each task and implementation artifact in **dmjl_port** directly to the lecture concepts defined in **Section 6.1** of the Computer Networks Course Project syllabus.

---

## 📚 Syllabus Alignment Matrix

| Lecture Course Topic | Specific Concept Tested | Implementation in dmjl_port | Tangible Proof / Evidence Artifact |
|---|---|---|---|
| **Moving Data Through the Core** | Packet routing across LAN segments, default gateways, and frame forwarding. | Traffic originates at client (Mac 4), travels through local switches/APs to Mac 2 (edge), and is forwarded to Mac 3/4. | Packet capture: [`dmjl_phase1_capture.pcapng`](../evidence/ev_mac3/dmjl_phase1_capture.pcapng)<br/>Ping mesh: [`A5_pings_mac1.txt`](../evidence/ev_mac1/A5_pings_mac1.txt). |
| **OSI vs TCP/IP Model** | Layer separation, encapsulation, and protocol boundaries. | Full architectural layer mapping showing DNS (L7), HTTP (L7), TLS (L6), TCP/UDP (L4), IP (L3), 802.11 (L2). | Architecture Document: [`ARCHITECTURE.md`](../ARCHITECTURE.md#4-multi-layer-osi--tcpip-protocol-stack-mapping). |
| **Devices, Topologies, Cloud Concepts** | Network topologies, private domains, edge proxies, and cloud parity. | Mapping local DNS, edge proxy, and backend replicas to AWS Route 53, AWS ALB, and Amazon EC2 target groups. | README Topology: [`README.md`](../README.md#2-physical-network-topology)<br/>Architecture: [`ARCHITECTURE.md`](../ARCHITECTURE.md#1-network-topology--physical-node-inventory). |
| **HTTP/1.1, HTTP/2, REST** | RESTful stateless endpoints, HTTP verb processing, status codes, and HTTP versioning. | Python REST backend supporting `GET /` (200), `GET /api/status` (200/304), Clients reach nginx over HTTP/1.1 (ALPN `http/1.1`; HTTP/2 not enabled); nginx forwards the request to the backend as HTTP/1.1 and the Python backend answers with HTTP/1.0 (see the v2 capture, frames 755/760). | Source: [`backend/server.py`](../backend/server.py)<br/>Telemetry: [`B2_lb_6x.txt`](../evidence/ev_mac4/B2_lb_6x.txt). |
| **HTTPS and TLS** | TLS 1.3 handshake, asymmetric encryption, cipher suites, X.509 cert validation, SNI, and TLS termination. | OpenSSL CA generation, SAN certificate for `*.dmjl.test`, TLS 1.3 termination at Nginx, client trust store injection (no `-k`). | OpenSSL script: [`tls/make-certs.sh`](../tls/make-certs.sh)<br/>Curl handshake: [`B1_curl_v.txt`](../evidence/ev_mac4/B1_curl_v.txt)<br/>Wireshark traces: [`C3_tls.png`](../evidence/ev_mac3/C3_tls.png), [`C3_cert.png`](../evidence/ev_mac3/C3_cert.png). |
| **DNS and Route 53 Concepts** | DNS resolution, A records, TTL caching, recursive forwarding, split-horizon DNS. | `dnsmasq` local records for `app.dmjl.test` and `api.dmjl.test` (TTL 30s) pointing to Mac 2; upstream fallback for external internet. | Config: [`dns/dnsmasq.conf`](../dns/dnsmasq.conf)<br/>Client Dig: [`A3_dig_client.txt`](../evidence/ev_mac4/A3_dig_client.txt)<br/>Public NXDOMAIN: [`A4_dig_8888.txt`](../evidence/ev_mac4/A4_dig_8888.txt). |
| **Transport Layer; Ports; TCP/UDP** | Socket 5-tuples, ephemeral vs well-known ports, UDP datagrams vs connection-oriented TCP streams. | Ephemeral source ports communicating with UDP 53 (DNS) and TCP 443 (HTTPS), TCP 3-way handshake (SYN, SYN-ACK, ACK). | Wireshark capture: [`C2_tcp.png`](../evidence/ev_mac3/C2_tcp.png)<br/>Socket mapping: [`ARCHITECTURE.md`](../ARCHITECTURE.md#5-port-identification--socket-pair-mapping). |
| **Reliable Data Transfer; TCP Flow Control** | Sequence numbers, acknowledgment numbers, window sizing, and connection state machine. | Wireshark inspection of TCP sequence/ack progression during TLS payload exchange and HTTP streaming. | Wireshark capture: [`C2_tcp.png`](../evidence/ev_mac3/C2_tcp.png)<br/>Raw pcapng: [`dmjl_phase1_capture.pcapng`](../evidence/ev_mac3/dmjl_phase1_capture.pcapng). |
| **CDNs and Caching** | HTTP caching semantics, cache validation, conditional requests, Cache-Control directives, and ETags. | Backend emits `Cache-Control: public, max-age=60` and `ETag: "status-v1"`; client issues `If-None-Match`, backend responds with `304 Not Modified`. | Response headers: [`D1_headers.txt`](../evidence/ev_mac4/D1_headers.txt)<br/>304 trace: [`D1_304.txt`](../evidence/ev_mac4/D1_304.txt). |
| **Cloud Load Balancing** | Layer-7 reverse proxying, round-robin upstream scheduling, passive health checks, high availability failover. | Nginx upstream load balancer alternating requests between Backend A (`:3001`) and Backend B (`:3002`); instant failover upon backend crash. | Nginx config: [`nginx/nginx.conf`](../nginx/nginx.conf)<br/>Alternation trace: [`B2_lb_6x.txt`](../evidence/ev_mac4/B2_lb_6x.txt)<br/>Failover trace: [`D3_after.txt`](../evidence/ev_mac4/D3_after.txt). |

---

## 🔬 In-Depth Concept Explanations for Evaluation & Viva

### 1. Why use `.test` instead of `.local`?
- RFC 2606 reserves `.test` specifically for testing and network evaluation.
- macOS reserves `.local` for Multicast DNS (mDNS / Bonjour via RFC 6762 on UDP port 5353). Using `.local` causes macOS to bypass unicast DNS (dnsmasq) and search for local mDNS responders, leading to resolution failures or high query latency.

### 2. DNS Resolution vs. TCP/HTTPS Connection
- **DNS Resolution:** Occurs first over UDP port 53. It is stateless and acts solely as an address directory lookup to discover the IP address corresponding to a hostname.
- **TCP/HTTPS Connection:** Occurs next over TCP port 443. It establishes a stateful, reliable connection (SYN/SYN-ACK/ACK), completes cryptographic key exchange (TLS), and transfers encrypted HTTP request/response payloads.

### 3. Fresh Cache Hit vs. Conditional Request (304) vs. Full New Request
- **Fresh Cache Hit:** The client checks its local cache; if `current_age < max-age` (60s), the cached representation is served immediately without making any network request.
- **Conditional Request (304 Not Modified):** The cache has expired (`current_age >= max-age`). The client issues an HTTP GET with `If-None-Match: "status-v1"`. The server validates the entity tag; if identical, it sends `304 Not Modified` with headers only (zero payload bytes transferred), saving bandwidth and latency.
- **Full New Request (200 OK):** The client has no cache, or sends `Cache-Control: no-cache`. The server executes the full handler and returns `200 OK` along with the full response body.
