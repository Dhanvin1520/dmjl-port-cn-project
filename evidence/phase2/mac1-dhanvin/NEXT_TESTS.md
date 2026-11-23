# Mac 1 live tests — completed

All Mac 1 live tests from the Phase 2 plan were run on 21–23 November 2026. Each result below comes from captured output.

| Test | Result | Evidence |
|---|---|---|
| Start primary DNS (`dns/start-phase2-primary.command`) | Running on `10.239.23.157:53` | `05-primary-dns-runtime.txt` |
| `dig @10.239.23.157 app.dmjl.test` | `10.239.23.87`, TTL 30 | `05-primary-dns.txt` / `.png` |
| Trusted HTTPS through Jagruthi's nginx | TLS verified, HTTP 200, no `-k` | `06-trusted-https.png`; `../mac2-jagruthi/06-trusted-https.txt` |
| HTTPS requests reach Backend A and Backend B | Alternating A/B | `07-load-balancing.png`; `../mac2-jagruthi/07-nginx-load-balancing.txt` |
| Primary DNS stopped, backup answers | Lookup still resolved via `10.239.23.49` | `../mac3-chaitanya/09-primary-down.txt`, `../mac4-lalith/10-backup-dns-log-mac4.txt` |
| Backend firewall isolation and rollback | Client blocked, site still worked, rollback restored access | `13-client-blocked.txt`, `15-domain-works.txt`, `16-firewall-rollback.png` |
| DNS cutover and manual cache flush | Cutover `.87 → .127` and restore; TTL and flush effects captured | `17-primary-cutover-*`, `19-primary-dns-restored.png`, `../mac4-lalith/18-warm-client-repeat-mac4.txt`, `../mac4-lalith/19-manual-flush-repeat-mac4.txt` |

Full status: [`../README.md`](../README.md). Report: [`../../../docs/PHASE2_FINAL_REPORT.md`](../../../docs/PHASE2_FINAL_REPORT.md).
