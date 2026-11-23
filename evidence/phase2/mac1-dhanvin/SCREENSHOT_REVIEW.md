# Screenshot review - 2026-11-21

## Accepted evidence

- `01-members.png` - shows four total and four authorized ZeroTier devices. It
  also contains trusted HTTPS output, so the same source image is retained as
  `06-trusted-https.png`.
- `02-zerotier-address.png` - shows `feth2917`, `10.239.23.157` and active status.
- `03-pings.png` - shows Mac 2, Mac 3 and Mac 4 all reachable with 0% packet loss.
- `05-primary-dns.png` - shows `NOERROR`, TTL 30, answer `10.239.23.87` and
  DNS server `10.239.23.157#53`.
- `06-trusted-https.png` - shows ordinary resolution to `10.239.23.87` and
  trusted HTTPS returning HTTP 200 with `X-Backend: A`.
- `08-cache-304.png` - shows the initial HTTP 200 with Cache-Control/ETag and
  the conditional HTTP 304 response.
- `07-load-balancing.png` - shows ten HTTP 200 responses distributed between
  `X-Backend: A` and `X-Backend: B`.
- `13-client-blocked.png` - shows direct client connections to Backend A and
  Backend B timing out while the backend firewall rules are active.
- `15-domain-works.png` - shows the public project path still returning HTTP
  200 through nginx while direct backend access is blocked.
- `16-firewall-rollback.png` - shows both direct backend requests returning
  HTTP 200 after the PF rules were rolled back. The attempted `tee` failed
  because the command ran outside the repository, but the visible results are
  valid screenshot evidence.

## Rejected or partial captures

These are retained under `rejected/` for traceability and must not be included
as final evidence:

- `03-pings-partial-mac4-timeout.png` - Mac 2 and Mac 3 pass, but Mac 4 times
  out and the final summary is not visible. Retake after Lalith is online.
- `06-invalid-pasted-output-as-commands.png` - output text was pasted back into
  the shell and produced `command not found`; this is not valid evidence.
- `08-cache-200-only.png` - only the 200 response is visible; the accepted
  `08-cache-304.png` contains both the 200 and 304 proof.

## Screenshots still required for later Phase 2 tests

- Standby-edge DNS cutover: fresh client, warm client, and manual flush.
- Phase 2 Wireshark DNS, TCP, and TLS captures.
- Final troubleshooting rehearsal and restored-service proof.
