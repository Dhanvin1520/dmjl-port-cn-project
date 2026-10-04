# Phase 1 Evaluation & Demonstration Checklist

> **Purpose:** Pre-evaluation verification guide matching the **Section 8 Final Demonstration Sequence** and **Section 12 Review 1 Rubric (50 Marks)**.

---

## 📋 Section 8 Live Demonstration Sequence (Steps 1–8 for Phase 1)

| Step | Demonstration Step | Required Action / Command | What the Evaluator Expects to See | Verified Evidence Artifact | Status |
|---|---|---|---|---|---|
| **1** | **Show topology and IP/service inventory** | Display [`ARCHITECTURE.md`](../ARCHITECTURE.md) and [`README.md`](../README.md) | Network diagram, IP table, role breakdown, and cloud equivalents. | [`ARCHITECTURE.md`](../ARCHITECTURE.md) | ✅ Passed |
| **2** | **Confirm all machines on private LAN** | `ping -c 4 <teammate_ip>` across all node pairs | 0.0% packet loss between all 4 physical MacBooks. | [`A5_pings_mac1.txt`](../evidence/ev_mac1/A5_pings_mac1.txt)<br/>[`A5_pings_mac2.txt`](../evidence/ev_mac2/A5_pings_mac2.txt) | ✅ Passed |
| **3** | **Resolve private domain from client** | `dig app.dmjl.test` | Resolves to Mac 2 (`10.7.21.15`) via Mac 1 DNS (`10.7.7.61#53`). | [`A3_dig_client.txt`](../evidence/ev_mac4/A3_dig_client.txt) | ✅ Passed |
| **4** | **Open service over HTTPS using domain name** | `curl -v https://app.dmjl.test/api/status` or Safari | Clean TLS 1.3 handshake, trusted CA, no warning, NO `-k` flag. | [`B1_curl_v.txt`](../evidence/ev_mac4/B1_curl_v.txt) | ✅ Passed |
| **5** | **Show load balancing across both backends** | `for i in {1..6}; do curl -sI https://app.dmjl.test/api/status \| grep -i x-backend; done` | Alternating `X-Backend: A` and `X-Backend: B`. | [`B2_lb_6x.txt`](../evidence/ev_mac4/B2_lb_6x.txt) | ✅ Passed |
| **6** | **Show Wireshark evidence of DNS, TCP, and TLS** | Open [`dmjl_phase1_capture.pcapng`](../evidence/ev_mac3/dmjl_phase1_capture.pcapng) in Wireshark | DNS query/answer, TCP 3-way handshake (SYN, SYN-ACK, ACK), TLS Client/Server Hello & Cert. | [`C1_dns.png`](../evidence/ev_mac3/C1_dns.png)<br/>[`C2_tcp.png`](../evidence/ev_mac3/C2_tcp.png)<br/>[`C3_tls.png`](../evidence/ev_mac3/C3_tls.png) | ✅ Passed |
| **7** | **Show HTTP headers and caching behavior** | `curl -sI https://app.dmjl.test/api/status`<br/>`curl -sI -H 'If-None-Match: "status-v1"' https://app.dmjl.test/api/status` | `Cache-Control: max-age=60`, `ETag: "status-v1"`, and HTTP `304 Not Modified`. | [`D1_headers.txt`](../evidence/ev_mac4/D1_headers.txt)<br/>[`D1_304.txt`](../evidence/ev_mac4/D1_304.txt) | ✅ Passed |
| **8** | **Fail one backend and prove service continues** | Stop Backend A (`Ctrl+C`), execute client requests | Automatic failover to Backend B, 100% HTTP 200, zero client connection errors. | [`D3_before.txt`](../evidence/ev_mac4/D3_before.txt)<br/>[`D3_after.txt`](../evidence/ev_mac4/D3_after.txt)<br/>[`D3_restored.txt`](../evidence/ev_mac4/D3_restored.txt) | ✅ Passed |

---

## 🏆 Review 1 Rubric Breakdown (50 Marks)

| Evaluation Area | Allocated Marks | Success Condition in Syllabus | Verification in Repository |
|---|---|---|---|
| **LAN Setup + Private DNS Configuration (Tasks A + B)** | **10 Marks** | Topology verified, pairwise ping (0% loss), DNS records resolving, client resolver pointed to Mac 1. | Fully verified in [`ARCHITECTURE.md`](../ARCHITECTURE.md), [`A1_mac1.txt`](../evidence/ev_mac1/A1_mac1.txt), [`A5_pings_mac1.txt`](../evidence/ev_mac1/A5_pings_mac1.txt), and [`A3_dig_client.txt`](../evidence/ev_mac4/A3_dig_client.txt). |
| **HTTP/REST Backends + Reverse Proxy + Load Balancing (Tasks C + D)** | **10 Marks** | Both backends running on ports 3001 & 3002, Nginx upstream configured, `X-Backend` header alternating. | Tested in [`backend/server.py`](../backend/server.py), [`nginx/nginx.conf`](../nginx/nginx.conf), and [`B2_lb_6x.txt`](../evidence/ev_mac4/B2_lb_6x.txt). |
| **HTTPS / TLS Correctness and Explanation (Task E)** | **8 Marks** | Valid X.509 certificate setup, Nginx TLS termination on port 443, TLS handshake captured and explained, no `-k` flag. | Validated in [`tls/make-certs.sh`](../tls/make-certs.sh), [`B1_curl_v.txt`](../evidence/ev_mac4/B1_curl_v.txt), and [`C3_tls.png`](../evidence/ev_mac3/C3_tls.png). |
| **Packet Analysis and Protocol Flow Evidence (Task G)** | **7 Marks** | Wireshark captures: DNS, TCP handshake, TLS, ephemeral source ports and well-known destination ports identified. | Documented in [`C1_dns.png`](../evidence/ev_mac3/C1_dns.png), [`C2_tcp.png`](../evidence/ev_mac3/C2_tcp.png), [`C3_cert.png`](../evidence/ev_mac3/C3_cert.png), and [`dmjl_phase1_capture.pcapng`](../evidence/ev_mac3/dmjl_phase1_capture.pcapng). |
| **HTTP Caching and Transport Layer Understanding (Task F)** | **5 Marks** | `Cache-Control` shown, conditional request with `ETag` yielding `304 Not Modified` or cache hit demonstrated. | Implemented in [`backend/server.py`](../backend/server.py) and documented in [`D1_headers.txt`](../evidence/ev_mac4/D1_headers.txt) & [`D1_304.txt`](../evidence/ev_mac4/D1_304.txt). |
| **Individual Viva Phase 1 Concepts** | **10 Marks** | Per-student ability to explain architecture, layer isolation, and troubleshooting methodology. | Comprehensive study notes provided in [`COURSE_TOPIC_MAPPING.md`](COURSE_TOPIC_MAPPING.md) and [`FAILURE_ANALYSIS.md`](FAILURE_ANALYSIS.md). |
| **Total Phase 1 Marks** | **50 Marks** | **Full Compliance** | **100% Ready for Evaluation** |
