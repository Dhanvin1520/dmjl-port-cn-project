# Phase 1 evidence

Real terminal output collected on each Mac. Folder = the Mac it was captured on.

| Form field | File |
|---|---|
| A1 machine IPs + roles | `ev_mac1/A1_mac1.txt`, `ev_mac2/A1_mac2.txt`, `ev_mac3/A1_mac3.txt`, `ev_mac4/A1_mac4.txt` |
| A2 dnsmasq config | `ev_mac1/A2_dnsmasq.txt` (full file: `ev_mac1/dnsmasq.conf`) |
| A3 dig from a client | `ev_mac4/A3_dig_client.txt` |
| A4 dig @8.8.8.8 | `ev_mac4/A4_dig_8888.txt` |
| A5 ping between all pairs | `ev_mac1/A5_pings_mac1.txt`, `ev_mac2/A5_pings_mac2.txt`, `ev_mac3/A5_pings_mac3.txt` |
| B1 curl -v HTTPS | `ev_mac4/B1_curl_v.txt` |
| B2 load balancing (6 requests) | `ev_mac4/B2_lb_6x.txt` |
| B3 nginx config | `ev_mac2/B3_nginx.conf` |
| C1–C3 Wireshark | `ev_mac3/dmjl_phase1_capture.pcapng`, `ev_mac3/C1_dns.png`, `ev_mac3/C2_tcp.png`, `ev_mac3/C3_tls.png`, `ev_mac3/C3_cert.png`, `ev_mac3/C_bonus_http.png` |
| D1 caching headers + 304 | `ev_mac4/D1_headers.txt`, `ev_mac4/D1_304.txt` |
| D3 failure demo (Option A) | `ev_mac4/D3_before.txt`, `ev_mac4/D3_layers.txt`, `ev_mac4/D3_after.txt`, `ev_mac4/D3_restored.txt` |
