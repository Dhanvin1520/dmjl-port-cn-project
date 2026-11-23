# Phase 2 Final Report — dmjl_port (Section C)

**Harden & Recover.** Phase 2 extends the Phase 1 platform with a backup DNS server, a controlled DNS record change, backend isolation, backend failover, a standby edge with DNS-based cutover, and a troubleshooting rehearsal. Tests ran on 21–23 November 2026. All evidence is in [`evidence/phase2/`](../evidence/phase2/), with an audit in [`evidence/phase2/README.md`](../evidence/phase2/README.md).

| Member | Mac | Phase 2 role |
|---|---|---|
| Dhanvin Vadlamudi (Team Lead) | Mac 1 · `10.239.23.157` | Primary DNS |
| Jagruthi Pulumati | Mac 2 · `10.239.23.87` | Primary nginx edge (TLS) |
| Chaitanya Sai Meka | Mac 3 · `10.239.23.127` | Backend A :3001, standby edge, packet capture |
| Kasula Lalithendra | Mac 4 · `10.239.23.49` | Backend B :3002, backup DNS, test client |

---

## 1. What changed from Phase 1

| Area | Phase 1 | Phase 2 |
|---|---|---|
| Network | Campus Wi-Fi (`10.7.x.x`, `10.3.x.x`) | Private ZeroTier virtual LAN `10.239.23.0/24` (`feth2917`, MTU 2800) — one member was out of station; approved by the faculty |
| DNS | One server (Mac 1) | Primary (Mac 1) + **backup** (Mac 4) with identical records; clients list both |
| Client resolver | System DNS set to Mac 1 | Scoped `/etc/resolver/dmjl.test` → `.157`, then `.49` |
| Edge | One nginx (Mac 2) | Primary nginx (Mac 2) + **standby nginx** (Mac 3) with an identical config |
| Backends | Reachable by anyone on the LAN | **pf**: ports 3001/3002 accept only the edge `10.239.23.87` |
| Failure handling | Backend failover shown once | Backend failover + DNS failover + edge migration + troubleshooting rehearsal |

Unchanged: the Python backends, the TLS certificate for `app.dmjl.test` (issued by `dmjl_port Local CA`), the round-robin upstream with `max_fails=1 fail_timeout=10s`, TTL 30 s, and `Cache-Control: public, max-age=60` + `ETag`.

---

## 2. Baseline on the new network

| Check | Result | Evidence |
|---|---|---|
| ZeroTier addresses | All four Macs online at the planned `10.239.23.x` addresses | `*/0[12]-zerotier-address*` |
| Reachability | All six pairs replied with 0% loss | `mac1-dhanvin/03-ping-*.txt`, `mac4-lalith/03-pings-mac4.txt`, `mac2-jagruthi/02,03-*` |
| DNS | Both servers answer `app.dmjl.test 30 IN A 10.239.23.87` | `mac1-dhanvin/05-primary-dns.txt`, `mac4-lalith/05-backup-dns-mac4.txt` |
| Trusted HTTPS | TLS 1.3, `SSL certificate verify ok`, HTTP 200, no `-k` | `mac2-jagruthi/06-trusted-https.txt`, `mac4-lalith/06-trusted-https-mac4.txt` |
| Load balancing | Alternating `X-Backend: A` / `B` | `mac2-jagruthi/07-nginx-load-balancing.txt`, `mac4-lalith/07-load-balancing-mac4.txt` |
| Caching | `200` then `304 Not Modified` with `Cache-Control` and `ETag` | `mac4-lalith/08-cache-304-mac4.txt` |

**Packet capture** (`mac3-chaitanya/phase2-capture.pcapng`, 35 packets, from Mac 3):

| Frames | What | Detail |
|---|---|---|
| 2 → 4 | DNS | `10.239.23.127` → `10.239.23.157:53`, ID `0x373e`, answer `10.239.23.87` |
| 7 → 8 → 9 | TCP handshake | `10.239.23.127:59529` ↔ `10.239.23.87:443`; **MSS 2760** = ZeroTier MTU 2800 − 20 (IP) − 20 (TCP) |
| 10 → 13 | TLS 1.3 | ClientHello (SNI `app.dmjl.test`) → ServerHello + ChangeCipherSpec + encrypted records |

---

## 3. Resilience tests and results

### Extension A — Backup DNS resolver

| Step | Result | Evidence |
|---|---|---|
| Primary DNS stopped | `dig @10.239.23.157` → `connection timed out; no servers could be reached` | `mac3-chaitanya/09-primary-down.txt` (21 Nov, 21:05) |
| Normal lookup on the client | Still resolved `app.dmjl.test` → `10.239.23.87` | same file |
| HTTPS | `HTTP/1.1 200 OK` through nginx | same file |
| Who answered | Backup log: `query[A] app.dmjl.test from 10.239.23.127` → `config app.dmjl.test is 10.239.23.87` | `mac4-lalith/10-backup-dns-log-mac4.txt` |

**Result:** with the primary down, the client's resolver timed out on `.157` and used `.49`; the service stayed reachable by name.

### Extension B — DNS TTL and controlled record change

| Step | Result | Evidence |
|---|---|---|
| TTL | Both servers answer with TTL **30** | `05-*` files |
| Record changed | `app.dmjl.test` → `10.239.23.127` on both servers (`api` kept on `.87` as a control) | `mac1-dhanvin/17-primary-cutover-*`, `mac2-jagruthi/17-dns-cutover.txt` |
| **Cached client keeps the old answer** | 23 Nov **12:27:48**: both servers answer `.127`, Lalith's warm client still reaches `edge=10.239.23.87 HTTP=200` | `mac4-lalith/18-warm-client-repeat-mac4.txt` (attempt 4) |
| Then switches by itself | **12:27:52**: same client reaches `edge=10.239.23.127 HTTP=200`, no flush | same file |
| **Manual flush** | **12:21:15**: both servers answer `.87`, client still reaches `.127` (cached); flush at **12:21:16** → immediately `edge=10.239.23.87 HTTP=200` | `mac4-lalith/19-manual-flush-repeat-mac4.txt` (attempt 2) |
| Fresh client | After a flush, a client that had no cache resolves `.127` immediately and gets HTTP 200 | `mac2-jagruthi/18-fresh-client-repeat.txt` |

Earlier attempts that missed the cache window are kept unchanged in the same files and are labelled as such.

### Extension C — Service isolation with pf

| Step | Result | Evidence |
|---|---|---|
| Rules loaded on both backends | Mac 3: allow `.87` → `3001`, block all other 3001. Mac 4: allow `.87` → `3002`, block others | `mac3-chaitanya/firewall-rules.txt`, `mac4-lalith/step5-firewall-active-mac4.txt` |
| Client connects directly | `curl … 10.239.23.127:3001` and `10.239.23.49:3002` → **timed out** (dropped) | `mac1-dhanvin/13-client-blocked.txt` |
| Edge connects directly | Both backends → `HTTP/1.0 200 OK` | `mac2-jagruthi/14-edge-allowed.txt` |
| Service by name | `https://app.dmjl.test` still → `HTTP/1.1 200 OK` | `mac1-dhanvin/15-domain-works.txt` |
| Rollback | Anchor flushed, pf token released, pf back to its original state; direct access works again | `mac4-lalith/step5-firewall-rollback-mac4.txt`, `mac1-dhanvin/16-firewall-rollback.png` |

### Extension D — High-availability backend failover

| Step | Result | Evidence |
|---|---|---|
| Backend A stopped | 6/6 requests `HTTP 200`, all `X-Backend: B`; DNS still resolves; direct connection to A refused | `mac4-lalith/11-backend-a-down-mac4.txt` |
| Backend A restarted | Direct A `200`; after `fail_timeout` the loop returns both A and B | `mac4-lalith/12-backend-a-restored-mac4.txt`, `mac3-chaitanya/backend-a-restart.txt` |

Single point of failure — see §5.

### Extension E — Controlled edge migration (DNS cutover)

| Step | Result | Evidence |
|---|---|---|
| Standby ready | Mac 3 runs nginx with a config **identical** to the primary's | `mac3-chaitanya/standby-nginx.conf` = `mac2-jagruthi/primary-edge-nginx.conf` |
| Both edges valid | With hostname verification on: `.87` → 200 (nginx/1.31.6), `.127` → 200 (nginx/1.31.9) | `mac4-lalith/17-edge-preflight-mac4.txt` |
| Cutover | DNS `.87 → .127`; fresh clients move at once, cached clients after TTL (12:27:48 → 12:27:52) | Extension B rows above |
| Restore | DNS back to `.87`; flush or TTL expiry returns clients to the primary | `mac1-dhanvin/19-primary-dns-restored.png`, `mac4-lalith/19-manual-flush-repeat-mac4.txt` |

### Extension F — Troubleshooting rehearsal

On 22 Nov (16:50) Backend A was stopped as a practice fault (a rehearsal, not the faculty-injected fault). Recorded by Lalith (`mac4-lalith/23-diagnosis-mac4.txt`), diagnosed by Jagruthi:

| Layer checked | Result |
|---|---|
| DNS (primary, backup, normal lookup) | All `10.239.23.87` ✔ |
| Edge port 443 | Open ✔ |
| HTTPS through nginx | 6/6 `200`, but **all `X-Backend: B`** — A missing |
| Direct Backend A `10.239.23.127:3001` | **Connection refused** |
| Direct Backend B | `200` ✔ |

**Diagnosis:** Backend A's process was down. "Connection refused" means the host is reachable but nothing is listening on 3001 — not a network or firewall problem (a firewall drop would time out instead). **Fix:** Backend A restarted; afterwards 8/8 requests returned 200 across A and B (`mac4-lalith/24-restored-mac4.txt`).

---

## 4. Troubleshooting findings

1. **Refused vs timed out tells you the layer.** A refused TCP connection (RST) means the host is up and the port is closed — an application problem. A timeout means packets are dropped — firewall, routing or a host that is down. We saw both: refused when Backend A was stopped, timeouts when pf blocked direct access.
2. **The resolver prefers the first server.** While only the backup had been switched to `.127`, the warm client kept resolving `.87` from the primary (attempts 1 and 3 of the cutover). Both servers must be changed together, and quickly, or clients get different answers depending on which server they ask.
3. **Catching a TTL window needs coordination.** Three of four cutover attempts and one of two flush attempts missed the 30 s window because the DNS switch and the client loop were not in step. Every attempt is kept as recorded.
4. **A firewall must be updated with the topology.** The pf rules allow only the primary edge; a standby edge would be blocked. We rolled pf back before the migration test; in production both edge addresses would be allowed.
5. **Occasional timeouts to the primary edge** (`HTTP=000` in the warm-client loops) came from the relayed ZeroTier path to Mac 2 in another city; repeated requests on the same path succeeded.
6. **Using `--resolve` keeps TLS verification on.** To test one edge directly we pinned the name to an IP with `curl --resolve` instead of using `-k`, so certificate checks stayed active.

---

## 5. Remaining single point of failure

The primary nginx edge on Mac 2 carries all traffic. DNS is redundant and the backends are a pair, but if the edge fails, clients reach the standby only after the DNS record is changed **and** their cached answer expires. To remove it: run two active edges behind one address (virtual IP with VRRP/keepalived), or put a load balancer or anycast address in front, or use health-checked DNS failover. A managed cloud load balancer spread across availability zones (e.g. AWS ALB) provides exactly this.

---

## 6. Learning summary

**A — Backup DNS.** DNS is just another service that can fail, and when it does the application is unreachable by name even though every server is healthy. Running a second server with identical records and listing both on the client turns that into a short timeout instead of an outage. We also learned the difference in symptoms: a DNS failure shows up as "could not resolve host", while an application failure resolves fine and then fails at TCP or HTTP.

**B — TTL and record change.** A DNS change does not take effect everywhere at once. Clients that already cached the answer keep using it until the TTL runs out — we saw a client reach the old edge while both servers already returned the new address, then switch four seconds later on its own. Flushing the cache forces the new answer immediately. This is why production migrations lower the TTL in advance and keep the old server running for at least one TTL.

**C — Service isolation.** The backends never need to be reachable by clients, only by the edge, so restricting them shrinks the attack surface without affecting users. pf's `quick` rules made the order explicit: allow the edge, drop everyone else. Keeping the rules in a separate anchor and recording the original pf state made the rollback clean and safe on personal laptops.

**D — Backend failover.** Passive health checks are enough for a small pool: nginx notices a refused connection, retries the same request on the other backend, and stops sending traffic to the failed one for `fail_timeout`. Users saw no errors. Failover at one layer, however, does not remove the single point of failure one layer up — the edge.

**E — Edge migration.** Because the certificate is bound to the name, not the IP, any edge with the same certificate and configuration can take over. DNS is the switch, and its TTL decides how fast clients follow; fresh clients moved immediately, cached ones after up to 30 seconds. Keeping both edges running during the change meant no client was ever sent to a dead address.

**F — Troubleshooting.** Checking layers in order — name, reachability, port, TLS, application — narrows a fault quickly and avoids guessing. In the rehearsal every lower layer passed, the `X-Backend` header showed only B, and a direct "connection refused" on port 3001 located the fault in one step. Reading the exact error (refused vs timeout) mattered more than any single tool.
