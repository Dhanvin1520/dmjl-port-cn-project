# Dhanvin screenshot checklist

Take screenshots only after the matching live test passes. Save them in this
folder using the exact names below.

## Take now

- `01-members.png` - ZeroTier Central showing all four authorized devices.
- `02-zerotier-address.png` - `ifconfig feth2917` showing `10.239.23.157`.
- `03-pings.png` - successful pings to `.87`, `.127` and `.49` with the summary lines.

## Take after primary DNS starts

- `05-primary-dns.png` - `dig @10.239.23.157 app.dmjl.test` showing
  `10.239.23.87` and TTL 30.
- `06-trusted-https.png` - verbose HTTPS request showing the domain, edge IP,
  certificate subject/issuer, `SSL certificate verify ok`, HTTP 200 and
  `X-Backend`. Do not use `-k`.
- `08-cache-304.png` - cache headers followed by the conditional request
  returning `304 Not Modified`.

`07-load-balancing.png` has now been captured successfully with both backends.

## Take during later Phase 2 tests

- `09-primary-dns-down.png` - direct query to primary fails while normal lookup
  and HTTPS still work through Lalith's backup DNS.
- `13-client-blocked.png` - direct requests from Mac 1 to backend ports fail.
- `15-domain-works.png` - domain HTTPS still returns 200 through nginx.
- `16-firewall-rollback.png` - direct backend request works after rollback.

Crop passwords, tokens, network join details and unrelated account information.
