# store.js

`src/store/store.js`

Main HTTP handler for the SafeHaven store. It routes incoming requests and enforces access through the injected auth adapter.

## Exports

### `handleStore(request, env, auth)`

Primary request handler for the store API.

It expects:

- `request`, the Cloudflare `Request`
- `env`, the Worker environment
- `auth`, an auth adapter object

The auth adapter must implement:

```js
{
  async getUser(request, env) {
    return { id, email, developerEnabled, admin } || null;
  }
}
```

### `runStoreAutoApprovals(env)`

Finds submissions whose `review_after` timestamp has passed and promotes them to live.

Call it from your Worker `fetch` handler with `ctx.waitUntil` so it can run in the background without blocking the request.

## Routes

| Method | Path | Access |
|---|---|---|
| GET | `/store/index.json` | Public |
| GET | `/store/catalog/:package` | Public |
| POST | `/store/apps` | Developer |
| GET | `/store/apps` | User |
| GET | `/store/apps/:id` | Owner or Admin |
| POST | `/store/apps/:id/verify-repo` | Owner |
| POST | `/store/apps/:id/submit` | Owner |
| DELETE | `/store/submissions/:id` | Owner |
| POST | `/store/submissions/:id/confirm-upload` | Owner |
| GET | `/store/submissions/:id` | Owner or Admin |
| GET | `/internal/store/pending-scans` | Scanner secret |
| POST | `/internal/store/scan-result` | Scanner secret |
| GET | `/admin/store/submissions` | Admin |
| POST | `/admin/store/submissions/:id/approve` | Admin |
| POST | `/admin/store/submissions/:id/reject` | Admin |
| POST | `/admin/store/apps/:id/trust-level` | Admin |
| POST | `/admin/store/apps/:id/status` | Admin |

## Access levels

| Level | Meaning |
|---|---|
| Public | No token required |
| User | Any authenticated user |
| Developer | Authenticated user with `developerEnabled: true` |
| Owner | Developer account that registered the app |
| Admin | User with `admin: true` in the normalised user object |
| Scanner secret | `x-vps-auth` header matches `SH_SCANNER_SECRET` |

## Submission lifecycle

```text
pending_upload -> pending_scan -> scanning -> pending_review -> live
                                                       -> rejected
```

A developer creates a submission, uploads the APK to the presigned staging URL, then calls `confirm-upload`.

The scanner picks up the submission, posts the scan result, and the submission moves to `pending_review` if it passes. An admin can approve it manually, or the auto-approval task can promote it after the review window.
