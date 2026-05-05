# sub_modules

Official APK scanner for the SafeHaven Store. Polls the store API for pending submissions, downloads each APK, runs it through the hash and engine pipeline, and posts the result back. Runs as a set of systemd services on any Linux VPS.

## How it works

1. Polls `GET /internal/store/pending-scans` on a configurable interval
2. Downloads each pending APK via its presigned URL
3. Computes SHA-256, extracts the signing certificate and manifest metadata
4. Checks the hash against the local VTTI hash server
5. If the optional engine is present, runs a full scan through it
6. Posts the merged verdict back to `POST /internal/store/scan-result`

Submissions that pass move to `pending_review`. Submissions that fail are immediately rejected.

## Services

The bootstrap installs and starts three systemd services:

**safehaven-scanner** runs the main APK scanner on port 8080.

**safehaven-hash** runs the local hash server on port 8081. It fetches recent malware hashes from MalwareBazaar every two hours and compiles them into a local SQLite database. The scanner queries this instead of any external hash API.

**safehaven-defs** polls the AVDatabase GitHub repository every 24 hours and downloads updated AV definitions into `optional_engine/defs/`. It restarts the scanner automatically after a successful update.

## Optional engine

If `optional_engine/lib/libcolourswift_av.so` and `libtensorflowlite_c.so` are present, the scanner loads the VX-TITANIUM engine and runs a full ML and YARA scan on each APK in addition to the hash check. If the files are not present the scanner runs hash-only without any errors.

To swap the engine for a different one, replace `scripts/vx_engine.py` with your own implementation. It needs to expose a single `scan(apk_path: str) -> dict` function that returns at minimum a `verdict` key with a value of `clean`, `malware`, or `unknown`. The rest of the pipeline does not need to change.

## Setup

```bash
scp -r scripts/ hash_server/ optional_engine/ scanner_bootstrap.sh root@your-server:/root/
ssh root@your-server
sed -i 's/\r//' scanner_bootstrap.sh
bash scanner_bootstrap.sh
```

Then edit `/root/.env`:

```env
CS_API_URL="https://your-store-api.com"
VPS_AUTH_SECRET="your-secret-here"
```

`VPS_AUTH_SECRET` must match `SH_SCANNER_SECRET` on your Worker. Then restart the scanner:

```bash
systemctl restart safehaven-scanner
```

## Health check

```bash
curl http://your-server:8080/health
curl http://localhost:8081/health
```

## Requirements

- Ubuntu 24.04 or similar
- Root access
- Python 3.10+

All Python dependencies are installed automatically by `scanner_bootstrap.sh`.

## Licence

MIT