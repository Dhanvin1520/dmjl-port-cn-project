# Phase 2 evidence audit | 22 November 2026 (updated 23 November)

Reviewed 52 screenshot files across four Mac folders, including duplicate and
rejected captures, and checked the matching records and the original packet capture
against sections 7–9 of the course brief. The local evidence shows baseline connectivity,
backup DNS failover, backend failover and recovery, firewall isolation on the project
network, DNS cutover and restoration, and the team troubleshooting rehearsal.
The TTL and manual-flush effects were captured in the 23 November repeat runs.

## Status — 23 November 2026

All Phase 2 extensions are evidenced. The remaining gaps from the 22 November audit are closed:

1. **Extensions B and E (TTL portion) — done.** `mac4-lalith/18-warm-client-repeat-mac4.txt/.png`
   (attempt 4): at 12:27:48 both DNS servers answered `.127` while the warm client still reached
   `.87` from its cache; at 12:27:52 it reached `.127` without a flush.
   `mac4-lalith/19-manual-flush-repeat-mac4.txt/.png` (attempt 2): at 12:21:15 both servers answered
   `.87` while the client still reached `.127`; after the flush at 12:21:16 it reached `.87` (HTTP 200).
   `mac2-jagruthi/18-fresh-client-repeat.txt/.png`: a flushed client resolved `.127` immediately.
   Attempts that missed the window are kept in the same files and labelled.
2. **Configuration bundle — done.** `mac3-chaitanya/standby-nginx.conf` (identical to
   `mac2-jagruthi/primary-edge-nginx.conf`) and `mac4-lalith/backup-dns.conf` are included;
   both are reproduced in `docs/CONFIGURATION_BUNDLE.md` §6.
3. **Submission documents — done.** `ARCHITECTURE.md` §7 (Phase 2 topology),
   `docs/CONFIGURATION_BUNDLE.md` §6 (Phase 2 configs, pf rules, rollback) and
   `docs/PHASE2_FINAL_REPORT.md` (changes, results, troubleshooting, learning per extension A–F).
   Mac 1 screenshots 01–08 are redacted (network ID, device IDs, public IPs); rejected captures
   are excluded via `.gitignore`. The ZeroTier virtual LAN was approved by the faculty.
4. **Evaluation — team.** Prepare the live demo, the faculty-injected fault and the individual viva.

## Mac 1 — Dhanvin

| Screenshot | Review |
|---|---|
| `01-members.png` | Four authorized members with the expected managed IPv4 addresses. Dashboard identifiers need redaction. |
| `02-zerotier-address.png` | Interface `feth2917` active at `10.239.23.157`. Redact the background dashboard for submission. |
| `03-pings.png` | Each of the other three Macs replied 3/3 with zero loss. The per-peer logs cover all three. Redact the background dashboard. |
| `05-primary-dns.png` | Primary DNS answered at `.157:53` with `.87` and TTL 30. Redact the background dashboard. |
| `06-trusted-https.png` | Same image as 01, also showing scoped resolvers and trusted HTTPS 200. Redact or crop to the terminal. |
| `07-load-balancing.png` | Ten successful requests alternate between A and B. Redact or crop to the terminal. |
| `08-cache-304.png` | 200 followed by a conditional 304 with Cache-Control and ETag. Redact or crop to the terminal. |
| `13-client-blocked.png` | Both direct backend connections timed out during the PF test. |
| `15-domain-works.png` | HTTPS through nginx still returned 200 during isolation. |
| `16-firewall-rollback.png` | Both direct backend checks returned HTTP 200 after rollback. The screenshot shows why the original `tee` did not write a text file. |
| `17-primary-cutover-preflight.png` | Cutover configuration syntax passed. App `.127`, API control `.87`, TTL 30. |
| `17-primary-cutover-runtime.png` | Running primary DNS logged app `.127` and API `.87`. |
| `17-primary-dns-cutover.png` | Direct queries confirmed app `.127` and API `.87` on the primary. |
| `19-primary-dns-restored.png` | Direct queries confirmed both names restored to `.87` on the primary. |
| `rejected/03-pings-partial-mac4-timeout.png` | Incomplete and superseded by successful pings. |
| `rejected/06-invalid-pasted-output-as-commands.png` | Shell errors from pasted output. Exclude from submission. |
| `rejected/08-cache-200-only.png` | The 304 response is offscreen. Use the later complete capture. |

The Mac 1 `06-trusted-https.txt` and `07-load-balancing.txt` describe earlier runs.
The former uses an explicit CA and address pinning, while the screenshot shows the
later scoped DNS and trust-store check. The latter lists six requests, while the
screenshot shows ten. Keep them as separately labeled runs. Use Jagruthi's or
Lalith's matching screenshot and text pairs when presenting baseline HTTPS and A/B.
The baseline 304 response is evidenced, but the backend's shared strong ETag is
the same for two JSON bodies with different backend IDs. Treat the capture as an
example of the observed conditional response.

## Mac 2 — Jagruthi

| Screenshot | Review |
|---|---|
| `06-nginx-running.png` | Certificate verification, nginx configuration test and port 443 listener visible. The filename listing contains no private key contents. |
| `06-trusted-https.png` | TLS 1.3, valid hostname and certificate, and HTTP 200 to the primary edge. |
| `07-nginx-load-balancing-valid.png` | Ten HTTP 200 responses alternating A and B. |
| `14-edge-allowed.png` | Direct tests from the edge reached both backends with HTTP 200 during PF isolation. |
| `17-dns-cutover.png` | Both DNS servers returned `.127` for the app. |
| `18-fresh-client.png` | Identical image as 17. The same capture also shows cache flush commands, normal lookup, and ordinary HTTPS 200 to `.127`. |
| `18-fresh-client-repeat.png` | 23 Nov 12:00:58: both DNS servers `.127`; after a flush the system lookup returned `.127` and HTTPS reached `edge=10.239.23.127 HTTP=200`. Terminal tab bar cropped. |

The Mac 2 address, pings to Macs 3 and 4, and baseline upstream results have
terminal exports. Those reachability results are also supported by the team captures.

## Mac 3 — Chaitanya (Meka)

| Screenshot | Review |
|---|---|
| `02-zerotier-address.png` | Private network status OK at `.127/24`. The latest ZIP redacts the network ID. |
| `09-primary-down.png` | Primary timed out while normal lookup returned `.87` and HTTPS returned 200. Pair with Mac 4's backup query log. |
| `09a-resolver-two-dns-servers.jpeg` | Resolver file lists both addresses. Supporting setup evidence. |
| `backend-a.png` | Backend A listening on 3001 and returning 200 to Mac 1. |
| `backend-a-restart.png` | Backend A resumed listening on port 3001. |
| `firewall-rules.png` | Active PF on Mac 3 shows the edge allow rule and port 3001 block rule. |
| `standby-nginx.png` | nginx syntax passed, both upstream probes worked and 443 was listening. The script prints a hard-coded Mac 2 banner. Mac 4's direct hostname-verified HTTPS to `.127` independently proves the standby. |
| `standby-nginx.conf` | The deployed standby config; identical to Mac 2's `primary-edge-nginx.conf`. |
| `20-dns.png` | Query and response in original capture frames 2 and 4, transaction `0x373e` (14142) matching the terminal log. Answer `.87`. |
| `21-tcp.png` | Frames 7–9 show SYN, SYN/ACK and ACK to the primary edge on TCP 443. |
| `22-tls.png` | Client and Server Hello in frames 10 and 13, with subsequent encrypted TLS records in the capture. The same-run curl log shows certificate verification and HTTPS 200. |
| `rejected/09-primary-dns-still-active-and-normal-resolution-failed.jpeg` | Initial attempt: the primary answered and ordinary resolution failed. Superseded by 09. |

The original `phase2-capture.pcapng` contains 35 packets and was decoded directly.
The packet run used `rootCA.pem` as the CA and retained certificate verification.
Mac 3's `24-backend-a-restored-runtime.txt` records Backend A listening and accepting
the Step 8 requests. Mac 4 provides the screenshot for the Mac 3–4 ping pair.

## Mac 4 — Lalith

| Screenshot | Review |
|---|---|
| `02-zerotier-address-mac4.png` | Online with private network status OK at `.49/24`. |
| `03-pings-mac4.png` | Replies from Mac 1, Mac 3 and Mac 2 over the ZeroTier interface, each 4/4. Together with Mac 1 and Mac 2 results this covers all six pairs. |
| `04-backend-B-mac4.png` | Backend B listening on 3002 and returning HTTP 200. |
| `05-backup-dns-mac4.png` | Backup and primary resolvers returned `.87` at TTL 30, and normal client lookup succeeded. |
| `06-trusted-https-mac4.png` | Valid TLS 1.3/hostname verification and HTTP 200. |
| `07-load-balancing-mac4.png` | Six HTTP 200 responses alternating B and A. |
| `08-cache-304-mac4.png` | Initial 200 and conditional 304 with Cache-Control and ETag. |
| `10-backup-dns-log-mac4.png` | Backup DNS handled a query from Mac 3 and returned `.87` during failover. |
| `11-backend-a-down-mac4.png` | Six HTTP 200 responses from B while A was unavailable. |
| `12-backend-a-restored-mac4.png` | A direct 200 and both A and B through nginx after restart. |
| `step5-firewall-active-mac4.png` | PF enabled with the edge allowed and other ZeroTier clients blocked on port 3002. |
| `step5-firewall-rollback-mac4.png` | Project rules cleared and prior PF state restored on Mac 4. |
| `17-edge-preflight-mac4.png` | Both edges returned 200 with hostname verification intact. |
| `18-warm-client-mac4.png` | Before/after migration verified. First loop ended at 15:58:53 while primary still returned `.87`. Second loop started at 16:05:51 after both servers returned `.127`. Cache retention across the change is shown by the repeat run below. |
| `18-warm-client-repeat-mac4.png` | Attempt 4: 12:27:48 both DNS servers `.127` while the warm client still reached `.87` (cached); 12:27:52 the client reached `.127` with no flush. Attempts 1–3 kept and labelled. |
| `19-manual-flush-mac4.png` | Both DNS servers and the client were already on `.87` before flushing. The screenshot proves restoration and successful HTTPS after the flush. The immediate cache-induced change is shown by the repeat run below. |
| `19-manual-flush-repeat-mac4.png` | Attempt 2: 12:21:15 both DNS servers `.87` while the client still reached `.127`; after the flush at 12:21:16 it reached `.87` with HTTP 200. Attempt 1 (missed window) kept and labelled. |
| `23-baseline-mac4.png` | Both resolvers on `.87` and six HTTP 200 responses from alternating A and B. |
| `23-diagnosis-mac4.png` | Both resolvers and port 443 healthy, six requests served by B, A direct connection failed, B direct HTTP 200. Records Jagruthi's diagnosis. |
| `24-restored-mac4.png` | A direct HTTP 200, and eight HTTP 200 responses across both backends. |

The earlier checkpoint records the state as of 21 November. Use this audit for the
22 November status. Screenshots that display saved terminal logs are indexed together
with their matching text output.
