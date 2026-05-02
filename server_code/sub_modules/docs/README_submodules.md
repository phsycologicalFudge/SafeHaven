# sub_modules

Official APK scanner for the SafeHaven Store. Polls the store API for pending submissions, downloads each APK, checks its hash against a malware database, and posts the result back. Runs as a systemd service on any Linux VPS.

## How it works

1. Polls `GET /internal/store/pending-scans` on a configurable interval
2. Downloads each pending APK via its presigned URL
3. Computes the SHA-256 of the APK
4. Checks the hash against a malware database
5. Posts the verdict back to `POST /internal/store/scan-result`

Submissions that pass move to `pending_review`. Submissions that fail are immediately rejected.

## Swapping the scanner internals

The hash check logic is isolated in `check_hashes()` inside `safehaven_scanner.py`. The default implementation hits the ColourSwift hash API, which is a private service and not intended for third party use. To use your own backend, replace `check_hashes()` with anything that accepts a list of SHA-256 strings and returns:

```python
{
    "verdict": "clean" | "known_malware" | "unknown",
    "matches": []
}
```

The rest of the scanner — polling, downloading, posting results — stays the same.

## Setup

```bash
scp safehaven_scanner.py root@your-server:/root/
scp scanner_bootstrap.sh root@your-server:/root/
ssh root@your-server
bash /root/scanner_bootstrap.sh
```

Then edit `/root/.env`:

```env
CS_API_URL="https://your-store-api.com"
VPS_AUTH_SECRET="your-secret-here"
POLL_INTERVAL="30"
```

`VPS_AUTH_SECRET` must match `SH_SCANNER_SECRET` on your Worker. Then:

```bash
systemctl restart safehaven-scanner
```

See [docs/scanner.md](../server_code/docs/scanner.md) for full details.

## Health check

```bash
curl http://your-server:8080/health
```

## Requirements

- Ubuntu 24.04 (or similar)
- Root access
- Python 3.10+

Dependencies are installed automatically by `scanner_bootstrap.sh`.

## Licence

MIT
