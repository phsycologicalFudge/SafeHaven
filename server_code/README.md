# SafeHaven Backend

This is the server-side infrastructure for SafeHaven. An android app distribution system focused on verification, transparency, and self-hostable deployment. It is built on Cloudflare Workers.

## Contents

- `safehaven_store/` - Cloudflare Worker handling all store routes, APK submissions, scanning, and the public app catalog
- `sub_modules/safehaven/` - Official APK scanner service (submodule)
- `cors.json` - CORS policy for the S3 bucket
- `docs/` - Documentation for all components

## Getting started

See [docs/COMPILE.md](docs/COMPILE.md) for full setup instructions covering the Worker, database, S3 bucket, and scanner service.

## Documentation

| File | Description |
|---|---|
| [docs/COMPILE.md](docs/COMPILE.md) | Full setup guide |
| [docs/store.md](docs/store.md) | Route reference and submission lifecycle |
| [docs/store_db.md](docs/store_db.md) | Database layer |
| [docs/storage.md](docs/storage.md) | S3 storage layer |
| [docs/auth.md](docs/auth.md) | Auth adapter interface |
| [docs/auth_demo.md](docs/auth_demo.md) | Demo adapter for self-hosted deployments |
| [docs/scanner.md](docs/scanner.md) | Scanner service |
| [docs/scanner_bootstrap.md](docs/scanner_bootstrap.md) | Scanner installation |

## Licence

MIT
