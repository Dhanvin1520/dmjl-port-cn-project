# Phase 2 evidence guide

Every test needs both the original terminal output (`.txt`) and a screenshot.
Do not submit screenshots alone. Never commit passwords, private TLS keys,
ZeroTier join details, tokens, account pages, or personal notifications.

## Team folders

```text
evidence/phase2/mac1-dhanvin/
evidence/phase2/mac2-jagruthi/
evidence/phase2/mac3-chaitanya/
evidence/phase2/mac4-lalith/
```

Create your own folder from the repository root:

```bash
mkdir -p evidence/phase2/mac1-dhanvin
mkdir -p evidence/phase2/mac2-jagruthi
mkdir -p evidence/phase2/mac3-chaitanya
mkdir -p evidence/phase2/mac4-lalith
```

## Save terminal output

Use `tee` so the command remains visible and is also saved:

```bash
COMMAND 2>&1 | tee evidence/phase2/YOUR-FOLDER/FILE.txt
```

Example:

```bash
ping -c 4 DESTINATION_IP 2>&1 \
  | tee evidence/phase2/mac2-jagruthi/03-ping-mac2-to-mac1.txt
```

For several commands, record the complete session:

```bash
script evidence/phase2/YOUR-FOLDER/session.txt
# Run commands
exit
```

Review every file before sending or committing it.

## Dhanvin - Mac 1

Folder: `evidence/phase2/mac1-dhanvin/`

Save:

- `01-inventory.txt`
- `02-zerotier-address.txt`
- `03-ping-mac1-to-mac2.txt`
- `03-ping-mac1-to-mac3.txt`
- `03-ping-mac1-to-mac4.txt`
- `05-primary-dns.txt`
- `09-primary-dns-down.txt`
- `13-client-blocked.txt`
- `15-domain-works.txt`
- `16-firewall-rollback.txt`
- `primary-dns.conf`

## Jagruthi - Mac 2

Folder: `evidence/phase2/mac2-jagruthi/`

Save:

- `02-zerotier-address.txt`
- `03-ping-mac2-to-mac3.txt`
- `03-ping-mac2-to-mac4.txt`
- `04-edge-to-backends.txt`
- `06-trusted-https.txt`
- `14-edge-allowed.txt`
- `17-dns-cutover.txt`
- `18-fresh-client.txt`
- `nginx-phase2.conf`
- `tls-notes.txt`

Save both direct backend checks together:

```bash
{
  curl -i http://CHAITANYA_IP:3001/api/status
  curl -i http://LALITH_IP:3002/api/status
} 2>&1 | tee evidence/phase2/mac2-jagruthi/04-edge-to-backends.txt
```

Never send or commit the TLS private key.

## Chaitanya - Mac 3

Folder: `evidence/phase2/mac3-chaitanya/`

Save:

- `02-zerotier-address.txt`
- `03-ping-mac3-to-mac4.txt`
- `09-backup-dns-client.txt`
- `11-backend-a-down.txt`
- `12-backend-a-restored.txt`
- `20-dns.png`
- `21-tcp.png`
- `22-tls.png`
- `phase2-capture.pcapng`
- `backend-firewall.pf`
- `standby-nginx.conf`

Start and record Backend A:

```bash
python3 backend/server.py A 3001 2>&1 \
  | tee evidence/phase2/mac3-chaitanya/backend-a-runtime.txt
```

Keep the backend terminal running and take a screenshot before stopping it.

## Lalith - Mac 4

Folder: `evidence/phase2/mac4-lalith/`

Save:

- `02-zerotier-address.txt`
- `05-backup-dns.txt`
- `06-trusted-https.txt`
- `07-load-balancing.txt`
- `08-cache-304.txt`
- `10-backup-dns-log.txt`
- `11-backend-a-down.txt`
- `12-backend-a-restored.txt`
- `18-warm-client.txt`
- `19-manual-flush.txt`
- `backup-dns.conf`
- `backend-firewall.pf`

Start and record Backend B:

```bash
python3 backend/server.py B 3002 2>&1 \
  | tee evidence/phase2/mac4-lalith/backend-b-runtime.txt
```

## Screenshots

Save screenshots beside the matching `.txt` file and use the same base name:

```text
07-load-balancing.txt
07-load-balancing.png
```

Every screenshot should show the full command, hostname or destination IP, and
the relevant result. Crop unrelated tabs, accounts and personal notifications.

## Sending files to Dhanvin

Each member sends one ZIP containing only their own folder:

```text
phase2-jagruthi.zip
phase2-chaitanya.zip
phase2-lalith.zip
```

Do not rename evidence after testing. Each member's evidence must go into a
separate Git commit, even if Dhanvin creates the commits from one Mac.
