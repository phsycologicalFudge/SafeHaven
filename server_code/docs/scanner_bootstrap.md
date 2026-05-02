# scanner_bootstrap.sh

`sub_modules/safehaven/scanner_bootstrap.sh`

Bootstrap script for installing the SafeHaven scanner on a fresh Ubuntu server. Run it once on the target VPS.

## What it installs

1. Installs `python3`, `python3-venv`, and `python3-pip` with apt
2. Creates a virtualenv at `/root/.venv`
3. Installs `fastapi`, `uvicorn`, and `httpx`
4. Writes `/root/.env` with placeholder config values
5. Creates and enables `safehaven-scanner.service`
6. Starts the scanner service and prints its status

## Usage

```bash
bash scanner_bootstrap.sh
```

## After installation

Edit `/root/.env` before using the scanner:

```env
CS_API_URL="https://your-store-api.com"
VPS_AUTH_SECRET="your-secret-here"
POLL_INTERVAL="30"
```

`VPS_AUTH_SECRET` must match the `SH_SCANNER_SECRET` value set on the Cloudflare Worker.

Restart the scanner after editing the env file:

```bash
systemctl restart safehaven-scanner
```

## Service commands

```bash
systemctl status safehaven-scanner
journalctl -u safehaven-scanner -f
systemctl restart safehaven-scanner
systemctl stop safehaven-scanner
```

## Requirements

- Ubuntu, tested on 24.04
- Root access
- `safehaven_scanner.py` copied to `/root/` before the service starts
