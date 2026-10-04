# Phase 1 Required Failure Demonstrations & Layer Isolation Analysis

> **Reference:** Course Project Specification — Section 6.3 & Section 8 Step 10  
> **Evaluation Objective:** Prove system understanding through deliberate fault injection and layer-by-layer diagnostic isolation.

---

## 🎯 Diagnostic Isolation Methodology

When a failure occurs in a networked distributed system, diagnosis must proceed hierarchically from lower to higher layers:
1. **Layer 3 (IP / ICMP):** Is the host reachable via `ping <IP>`?
2. **Layer 7 (DNS):** Does `dig @<DNS_IP> <name>` return the expected A record?
3. **Layer 4 (Transport / TCP):** Does `nc -zv <IP> <PORT>` or SYN handshake establish?
4. **Layer 6 (Security / TLS):** Does `openssl s_client -connect <IP>:<PORT>` complete the handshake and validate the CA chain?
5. **Layer 7 (Application / HTTP):** Does `curl -v http(s)://...` return the expected HTTP status code and payload?

---

## 🔬 Analysis of All 5 Mandatory Failure Scenarios

### Scenario 1: Wrong DNS Server Configured on a Client
- **Fault Injection:** Client's resolver is pointed to an arbitrary IP that does not run DNS or lacks the private zone (e.g., `sudo networksetup -setdnsservers Wi-Fi 10.7.7.99` or `dig @10.7.7.99 app.dmjl.test`).
- **Observed Behavior:**
  - `dig app.dmjl.test`: Returns `;; connection timed out; no servers could be reached` or `SERVFAIL`.
  - `curl https://app.dmjl.test/api/status`: Fails immediately with `curl: (6) Could not resolve host: app.dmjl.test`.
  - `ping 10.7.21.15` (Mac 2 Edge IP): **Succeeds with 0% packet loss!**
- **Layer Isolation Explanation:**
  Proves that the **DNS Layer (Application Layer / UDP 53)** and **IP Layer (Network Layer / Layer 3)** operate completely independently. Direct IP reachability exists at Layer 3, but the client cannot initiate transport connections without name-to-address resolution.

---

### Scenario 2: DNS Record Points to a Wrong IP Address
- **Fault Injection:** In `dnsmasq.conf`, set `address=/app.dmjl.test/10.7.7.199` (an unassigned IP or wrong node).
- **Observed Behavior:**
  - `dig app.dmjl.test`: **Succeeds with `status: NOERROR`**, returning `10.7.7.199`.
  - `curl https://app.dmjl.test/api/status`: Times out with `curl: (28) Failed to connect to app.dmjl.test port 443: Operation timed out` or `Connection refused`.
- **Layer Isolation Explanation:**
  Proves that **DNS is merely an address directory (mapping layer)**, not an active network connection. A successful DNS lookup provides zero guarantee that the destination host exists, is online, or is listening on the requested port.

---

### Scenario 3: One Backend Node is Stopped (Option A — Live Captured)
- **Fault Injection:** Kill Backend A process (`Ctrl+C` on Mac 3: `10.7.3.17:3001`).
- **Observed Behavior:**
  - DNS resolution to `app.dmjl.test`: Continues resolving to `10.7.21.15` normally ([`D3_layers.txt`](../evidence/ev_mac4/D3_layers.txt)).
  - ICMP ping to Mac 3 (`10.7.3.17`): Continues responding with 0% packet loss ([`D3_layers.txt`](../evidence/ev_mac4/D3_layers.txt)).
  - Client curl requests: 100% of repeated requests return `HTTP/1.1 200 OK` exclusively served by `X-Backend: B` ([`D3_after.txt`](../evidence/ev_mac4/D3_after.txt)).
  - Client error rate: **0.0%** (zero failed transactions).
- **Layer Isolation Explanation:**
  Nginx acts as a layer-7 reverse proxy with upstream fault tolerance (`max_fails=1 fail_timeout=10s; proxy_next_upstream error timeout http_502;`). When Nginx receives a TCP `RST` (connection refused) from port 3001, it immediately retries the request against Backend B within the same client session.
- **Evidence Files:**
  - Pre-failure balance: [`D3_before.txt`](../evidence/ev_mac4/D3_before.txt)
  - Lower layers verification: [`D3_layers.txt`](../evidence/ev_mac4/D3_layers.txt)
  - Failover state: [`D3_after.txt`](../evidence/ev_mac4/D3_after.txt)
  - Recovery state: [`D3_restored.txt`](../evidence/ev_mac4/D3_restored.txt)

---

### Scenario 4: Both Backend Nodes are Stopped
- **Fault Injection:** Terminate both Backend A (Mac 3) and Backend B (Mac 4).
- **Observed Behavior:**
  - `dig app.dmjl.test`: Fully functional (`NOERROR -> 10.7.21.15`).
  - `curl -v https://app.dmjl.test/api/status`:
    - TCP handshake to port 443: **Succeeds (SYN/ACK from Mac 2)**.
    - TLS 1.3 handshake: **Succeeds (Valid certificate presented by Mac 2)**.
    - HTTP Response: **`HTTP/1.1 502 Bad Gateway`** generated directly by Nginx.
- **Layer Isolation Explanation:**
  This clearly delineates **where the edge ends and the backend begins**:
  - The Edge reverse proxy is fully operational at Layers 3, 4, 6, and 7.
  - The application backend cluster is unavailable. The edge communicates this upstream failure to the client via RFC 7231 status code `502 Bad Gateway`.

---

### Scenario 5: Wrong Destination Port on the Client
- **Fault Injection:** Client attempts to connect to an unopened port on the edge (e.g. `curl https://app.dmjl.test:8443` or `curl https://app.dmjl.test:9999`).
- **Observed Behavior:**
  - DNS resolution succeeds immediately (`app.dmjl.test -> 10.7.21.15`).
  - Client TCP connection: Fails immediately with `curl: (7) Failed to connect to app.dmjl.test port 9999: Connection refused`.
  - Wireshark trace: Client sends `[SYN]` packet to destination port 9999; Mac 2 OS kernel immediately replies with `[RST, ACK]`.
- **Layer Isolation Explanation:**
  Proves that **IP addresses (Network Layer 3)** and **Port numbers (Transport Layer 4)** are distinct identifiers:
  - IP address identifies the physical/virtual host interface on the subnet.
  - Port number identifies the specific operating system socket/process bound to receive traffic.
