# safehaven_scanner.py

`sub_modules/safehaven/scripts/safehaven_scanner.py`

Python scanner service for APK submissions. It polls the store for pending scans, downloads each APK, runs it through the hash check and optional engine, then posts the result back to the store API. Runs as a systemd service on a Linux VPS.

## How it works

1. Polls `GET /internal/store/pending-scans` every `POLL_INTERVAL` seconds
2. Downloads each pending APK using the presigned URL returned by the store
3. Computes SHA-256, extracts the signing certificate hash and manifest metadata
4. For auto-tracked apps, checks the signing certificate against the stored key and rejects immediately on mismatch
5. Checks the hash against the local hash server at `/check_batch`
6. If the engine is available, runs a full scan via `engine.py`
7. Merges the results and posts to `POST /internal/store/scan-result`

If the hash is not known as malware and the engine does not flag it, the submission moves to `pending_review` and the review timer starts. Either layer finding malware causes an immediate rejection.

# My custom plugin

As an antivirus dev, I've included the vx-titanium engine that comes with my app. This is not required for the scanner to work, and you can implement your own engine or use VirusTotal. 

## Environment variables

| Var | Description | Default |
|---|---|---|
| `CS_API_URL` | Base URL of the store API | `https://your_api.nevergonnagiveyouup` |
| `VPS_AUTH_SECRET` | Shared secret matching `SH_SCANNER_SECRET` on the Worker | Required |
| `POLL_INTERVAL` | Seconds between scan polling cycles | `30` |
| `HASH_API_URL` | URL of the hash check endpoint | `http://127.0.0.1:8081/check_batch` |
| `HASH_API_KEY` | Key for the hash server | Required |
| `ENGINE_ENABLED` | Set to `0` to disable the engine even if the .so files are present | `1` |
| `VXTITANIUM_LIB_PATH` | Path to `libcolourswift_av.so` | `optional_engine/lib/libcolourswift_av.so` |
| `VXTITANIUM_DEFS_PATH` | Path to the defs directory | `optional_engine/defs` |
| `TFLITE_LIB_PATH` | Path to `libtensorflowlite_c.so` | `optional_engine/lib/libtensorflowlite_c.so` |

`VPS_AUTH_SECRET` is required. The service will not start without it.

## Result shape

The scanner posts the following fields to the store on each submission:

- `passed` whether the submission passed all checks
- `detail` the hash check result including verdict and any matches
- `engineResult` the engine scan result if the engine ran, including verdict, detections and version
- `apkSha256` SHA-256 of the downloaded APK
- `apkSize` size in bytes
- `signingKeyHash` SHA-256 of the signing certificate if extractable
- `packageName`, `manifestVersionCode`, `manifestVersionName` from the APK manifest if available
- `scannedAt` Unix timestamp

## Health endpoint

`GET /health` returns the current scanner config including engine status, API URL, poll interval and rescan cache size.

## Dependencies

- `fastapi`
- `uvicorn`
- `httpx`

`scanner_bootstrap.sh` installs these automatically.