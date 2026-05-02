# SafeHaven Store

A self-hostable Android app store backend built on Cloudflare Workers, D1, and S3-compatible object storage. Handles app registration, APK submission, scanning, review, and serving a public app catalog.

## What's included

- **Store API** — Cloudflare Worker handling all store routes, from developer submissions to the public catalog
- **Auth adapter system** — plug in your own login provider without touching store logic
- **Demo auth** — static bearer tokens for self-hosted deployments with no account system
- **Schema** — D1 SQLite migrations for the store tables

The scanner service lives in [sub_modules](https://github.com/your-org/sub_modules).

## Stack

- Cloudflare Workers
- Cloudflare D1 (SQLite)
- S3-compatible object storage (Hetzner, R2, B2, AWS S3)

## Getting started

See [docs/COMPILE.md](docs/COMPILE.md) for full setup instructions.

## Documentation

| File | Description |
|---|---|
| [docs/store.md](docs/store.md) | Route reference, auth levels, submission lifecycle |
| [docs/store_db.md](docs/store_db.md) | Database layer |
| [docs/storage.md](docs/storage.md) | S3 storage layer |
| [docs/auth.md](docs/auth.md) | Auth adapter interface |
| [docs/auth_demo.md](docs/auth_demo.md) | Demo adapter |
| [docs/index_demo.md](docs/index_demo.md) | Worker entry point |
| [docs/COMPILE.md](docs/COMPILE.md) | Setup guide |

## Auth adapters

The store has no opinion on how users log in. You pass an auth adapter in at the entry point:

```js
export default {
  async fetch(request, env, ctx) {
    ctx.waitUntil(runStoreAutoApprovals(env));
    return handleStore(request, env, yourAuth);
  },
};
```

`auth_demo.js` uses static tokens from `wrangler.jsonc` and is suitable for personal or small team deployments. See [docs/auth.md](docs/auth.md) for the adapter interface.

## Licence

MIT
