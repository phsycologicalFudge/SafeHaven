# safehaven_scanner.py

`sub_modules/safehaven/safehaven_scanner.py`

Python scanner service for APK submissions. It polls the store for pending scans, downloads each APK, checks the SHA-256 hash against the malware hash API, then posts the result back to the store API.

The scanner is intended to run as a systemd service on a Linux VPS.

## Scan flow

1. Polls `GET /internal/store/pending-scans` every `POLL_INTERVAL` seconds
2. Downloads each pending APK using the presigned URL returned by the store
3. Computes the SHA-256 hash of the downloaded file
4. Checks the hash through the ColourSwift hash API at `/check_batch`
5. Posts the result to `POST /internal/store/scan-result`

If the hash is not known as malware, the submission moves to `pending_review` and the review timer starts. If the hash matches a known malware entry, the submission is rejected.

## Environment variables

| Var | Description | Default |
|---|---|---|
| `CS_API_URL` | Base URL of the store API | `https://api.colourswift.com` |
| `VPS_AUTH_SECRET` | Shared secret matching `SH_SCANNER_SECRET` on the Worker | Required |
| `POLL_INTERVAL` | Seconds between scan polling cycles | `30` |

`VPS_AUTH_SECRET` is required. The service will not start without it.

## Health endpoint

`GET /health` returns the current scanner config, including the API URL and poll interval. Use it for basic monitoring or load balancer checks.

## Dependencies

The scanner uses:

- `fastapi`
- `uvicorn`
- `httpx`

`scanner_bootstrap.sh` installs these automatically into the scanner virtualenv.
