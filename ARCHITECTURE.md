# Architecture Document — dmjl_port (Phase 1: Build & Observe)

> **Course:** Computer Networks Course Project  
> **Platform:** Private Network Service Platform  
> **Deployment Model:** 4 Physical macOS Laptops on Private LAN (Submission Type 1)  
> **Team:** Section C (Dhanvin Vadlamudi, Jagruthi Pulumati, Chaitanya Sai Meka, Kasula Lalithendra)  

---

## 1. Network Topology & Physical Node Inventory

The platform is deployed entirely on a private local area network (LAN) over physical Wi-Fi interfaces (`en0`) without relying on any external cloud infrastructure or public domain registries.

### Node Inventory & Role Specification

| Machine | Hostname / Node Name | Assigned Physical IP | Interface | Open Service Ports / Protocols | Primary Software Stack | Cloud Architecture Equivalent |
|---|---|---|---|---|---|---|
| **Mac 1** | `Dhanvin’s MacBook Pro` | `10.7.7.61` | `en0` | `53/UDP`, `53/TCP` | `dnsmasq` v2.90+ | AWS Route 53 Private Hosted Zone |
| **Mac 2** | `Jagruthi’s MacBook Pro` | `10.7.21.15` | `en0` | `443/TCP` (TLS), `80/TCP` (HTTP Redirect) | `nginx` v1.31+, OpenSSL 3.x | AWS Application Load Balancer (ALB) |
| **Mac 3** | `MacBook Pro` | `10.7.3.17` | `en0` | `3001/TCP` (HTTP) | Python 3 `http.server` (Node A) | Amazon EC2 Target Group Worker A |
| **Mac 4** | `kasula’s MacBook Pro` | `10.3.2.17` | `en0` | `3002/TCP` (HTTP) | Python 3 `http.server` (Node B) + Client Suite | Amazon EC2 Target Group Worker B + VPC Client |

- **Subnet Configuration:** Subnet masks `255.255.224.0` (`/19`) and `255.255.252.0` (`/22`), routed seamlessly via LAN default gateways (`10.7.0.1` / `10.3.0.1`).
- **Private Domain Namespace:** `app.dmjl.test` and `api.dmjl.test` (utilizing the RFC 2606 reserved `.test` Top-Level Domain to prevent leakage into public DNS and collision with macOS mDNS `.local`).

---

## 2. Network Topology Diagram

```mermaid
flowchart TD
    subgraph LAN["Physical Campus LAN (Wi-Fi Interface: en0)"]
        subgraph ClientNode["Client Workstation (Mac 4 / Mac 1)"]
            Client["Test Client<br/>(curl / Safari / Chrome)<br/>IP: 10.3.2.17"]
        end

        subgraph DNSNode["Mac 1 — Authoritative DNS (10.7.7.61)"]
            DNS["dnsmasq (Port 53/UDP)<br/>Authoritative zone: *.dmjl.test<br/>Upstream Forwarder: LAN DNS / 8.8.8.8"]
        end

        subgraph EdgeNode["Mac 2 — Edge Reverse Proxy & ALB (10.7.21.15)"]
            NGINX["nginx Edge Proxy<br/>Port 443 (TLS 1.3 Termination)<br/>Port 80 (301 HTTPS Enforcement)<br/>Round-Robin Upstream Balancer"]
        end

        subgraph BackendA["Mac 3 — Worker Node A (10.7.3.17)"]
            ServerA["Backend Instance A (:3001)<br/>Python REST Handler<br/>ETag & Cache-Control: max-age=60"]
        end

        subgraph BackendB["Mac 4 — Worker Node B (10.3.2.17)"]
            ServerB["Backend Instance B (:3002)<br/>Python REST Handler<br/>ETag & Cache-Control: max-age=60"]
        end
    end

    Client -- "1. DNS A Query: app.dmjl.test (UDP 53)" --> DNS
    DNS -- "2. Authoritative Answer: 10.7.21.15 (TTL 30s)" --> Client
    Client -- "3. TCP 3-Way Handshake + TLS 1.3 Handshake (Port 443)" --> NGINX
    NGINX -- "4a. Upstream HTTP Forward (Port 3001)" --> ServerA
    NGINX -- "4b. Upstream HTTP Forward (Port 3002)" --> ServerB
```

---

## 3. End-to-End Request Lifecycle & Protocol Flow

Every client transaction traverses the entire network stack across multiple physical machines. The detailed flow for a standard request (`curl https://app.dmjl.test/api/status`) is documented below:

```mermaid
sequenceDiagram
    autonumber
    participant C as Client (Mac 4: 10.3.2.17)
    participant D as DNS Server (Mac 1: 10.7.7.61)
    participant E as Edge Reverse Proxy (Mac 2: 10.7.21.15)
    participant A as Backend A (Mac 3: 10.7.3.17:3001)
    participant B as Backend B (Mac 4: 10.3.2.17:3002)

    Note over C,D: Stage 1: DNS Resolution (UDP Port 53)
    C->>D: Standard Query: A app.dmjl.test (UDP 53, Ephemeral Src Port)
    D-->>C: Standard Query Response: 10.7.21.15 (TTL=30, Authoritative)

    Note over C,E: Stage 2: Transport Layer Establishment (TCP Port 443)
    C->>E: TCP SYN [Seq=0] (Dest: 443, Src: Ephemeral)
    E-->>C: TCP SYN, ACK [Seq=0, Ack=1]
    C->>E: TCP ACK [Seq=1, Ack=1] (3-Way Handshake Completed)

    Note over C,E: Stage 3: TLS 1.3 Cryptographic Handshake
    C->>E: TLS ClientHello (SNI: app.dmjl.test, Supported Groups, Cipher Suites)
    E-->>C: TLS ServerHello (Selected Cipher: TLS_CHACHA20_POLY1305_SHA256)
    E-->>C: EncryptedExtensions, Certificate (CN=app.dmjl.test, SAN), CertVerify, Finished
    C-->>E: TLS Finished (Session Keys Derived, Symmetric Encryption Activated)
    Note over C: Client validates cert against trusted rootCA.pem (No -k flag needed)

    Note over C,A: Stage 4: Encrypted Application Exchange (Request 1)
    C->>E: Encrypted Application Data (HTTP GET /api/status)
    Note over E: Edge terminates TLS and performs reverse proxy lookup
    E->>A: Unencrypted HTTP/1.0 GET /api/status (Internal LAN: 10.7.3.17:3001)
    A-->>E: HTTP 200 OK + {"backend":"A","status":"ok"} + X-Backend: A + ETag: "status-v1"
    E-->>C: Encrypted HTTP/1.1 200 OK (Proxied via TLS, X-Backend: A)

    Note over C,B: Stage 5: Round-Robin Distribution (Request 2)
    C->>E: Encrypted Application Data (HTTP GET /api/status)
    E->>B: Unencrypted HTTP/1.0 GET /api/status (Internal LAN: 10.3.2.17:3002)
    B-->>E: HTTP 200 OK + {"backend":"B","status":"ok"} + X-Backend: B + ETag: "status-v1"
    E-->>C: Encrypted HTTP/1.1 200 OK (Proxied via TLS, X-Backend: B)
```

---

## 4. Multi-Layer OSI & TCP/IP Protocol Stack Mapping

This architecture directly demonstrates every layer of the classical OSI reference model and TCP/IP protocol suite:

| Layer (TCP/IP) | OSI Model Equivalent | Protocol in This Implementation | Operational Behavior & Evidence |
|---|---|---|---|
| **Application** | Layer 7 | **DNS** (`RFC 1035`) | Authoritative resolution of `.test` domain via `dnsmasq` on port 53. Evidence: [`A3_dig_client.txt`](evidence/ev_mac4/A3_dig_client.txt), [`C1_dns.png`](evidence/ev_mac3/C1_dns.png). |
| **Application** | Layer 7 | **HTTP/1.1 & REST** (`RFC 7230-7235`) | JSON payload exchange, `X-Backend` header routing, `Cache-Control: max-age=60`, conditional `If-None-Match` revalidation (`304 Not Modified`). Evidence: [`B2_lb_6x.txt`](evidence/ev_mac4/B2_lb_6x.txt), [`D1_304.txt`](evidence/ev_mac4/D1_304.txt). |
| **Presentation** | Layer 6 | **TLS 1.3** (`RFC 8446`) | Edge TLS termination on Nginx. Session encryption, X.509 certificate validation, perfect forward secrecy (PFS). Evidence: [`B1_curl_v.txt`](evidence/ev_mac4/B1_curl_v.txt), [`C3_tls.png`](evidence/ev_mac3/C3_tls.png). |
| **Session** | Layer 5 | **Sockets & TLS Sessions** | Session setup, teardown, socket management across client, edge, and backend pools. |
| **Transport** | Layer 4 | **TCP** (`RFC 793`) & **UDP** (`RFC 768`) | UDP 53 for lightweight DNS lookups; reliable connection-oriented TCP (SYN/SYN-ACK/ACK) on port 443, 3001, 3002. Evidence: [`C2_tcp.png`](evidence/ev_mac3/C2_tcp.png). |
| **Network** | Layer 3 | **IPv4 & ICMP** (`RFC 791, 792`) | Subnet addressing, packet routing across `10.7.x.x` and `10.3.x.x`, ICMP reachability verification with 0% loss. Evidence: [`A5_pings_mac1.txt`](evidence/ev_mac1/A5_pings_mac1.txt). |
| **Data Link** | Layer 2 | **IEEE 802.11 / Ethernet** | MAC addressing (`ether` hardware frames) over Wi-Fi interface `en0`. Evidence: [`A1_mac1.txt`](evidence/ev_mac1/A1_mac1.txt) - [`A1_mac4.txt`](evidence/ev_mac4/A1_mac4.txt). |
| **Physical** | Layer 1 | **Radio Frequency / Wi-Fi** | Physical 802.11 wireless medium connecting all 4 Apple silicon laptops. |

---

## 5. Port Identification & Socket Pair Mapping

Every active transaction is uniquely identified by a 5-tuple socket pair `(Source IP, Source Port, Destination IP, Destination Port, Protocol)`:

1. **DNS Transaction:**
   - **Source Socket:** `10.3.2.17 : <ephemeral-udp-port>` (Client)
   - **Destination Socket:** `10.7.7.61 : 53` (Well-known DNS UDP service port on Mac 1)
2. **Client to Edge Ingress:**
   - **Source Socket:** `10.3.2.17 : <ephemeral-tcp-port>` (Client)
   - **Destination Socket:** `10.7.21.15 : 443` (Well-known HTTPS TCP port on Mac 2)
3. **Edge to Backend A Egress:**
   - **Source Socket:** `10.7.21.15 : <ephemeral-tcp-port>` (Nginx upstream worker)
   - **Destination Socket:** `10.7.3.17 : 3001` (Fixed TCP service port on Mac 3)
4. **Edge to Backend B Egress:**
   - **Source Socket:** `10.7.21.15 : <ephemeral-tcp-port>` (Nginx upstream worker)
   - **Destination Socket:** `10.3.2.17 : 3002` (Fixed TCP service port on Mac 4)

---

## 6. TLS Offloading & Edge Security Architecture

In modern cloud production systems, CPU-intensive cryptographic handshakes and public certificate management are centralized at the application load balancer (ALB), while backend microservices communicate over high-throughput, low-latency private networks.

Our system implements this exact architecture:
- **Public / Client Boundary:** Port 443 with TLS 1.3 encryption, protecting sensitive payloads over the air.
- **Private Backend Boundary:** Ports 3001 & 3002 with unencrypted HTTP/1.0, verified live via packet analysis ([`C_bonus_http.png`](evidence/ev_mac3/C_bonus_http.png)).
