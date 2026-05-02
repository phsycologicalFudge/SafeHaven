# store_db.js

`src/store/store_db.js`

Cloudflare D1 database layer for the SafeHaven store. This file handles data access for store apps and submissions. It does not contain HTTP routing or auth logic.

## Tables

### `store_apps`

One row per registered app.

Tracks the developer owner, repo URL, repo verification state, signing key hash, trust level, and app status.

### `store_submissions`

One row per APK version submission.

Tracks the submission state from upload, through scanning and review, to either live or rejected.

## Constants

### `SUBMISSION_STATUS`

```text
pending_upload -> pending_scan -> scanning -> pending_review -> live | rejected
```

### `APP_STATUS`

```text
active
suspended
removed
```

### `TRUST_LEVEL`

```text
verified_source
security_reviewed
```

## Key functions

| Function | Purpose |
|---|---|
| `createStoreApp(env, input)` | Registers an app and generates a `repoToken` for ownership verification |
| `createSubmission(env, input)` | Creates a new version submission in `pending_upload` |
| `advanceSubmissionToScan(env, id)` | Moves a confirmed upload from `pending_upload` to `pending_scan` |
| `markSubmissionScanning(env, id)` | Moves a submission from `pending_scan` to `scanning` |
| `recordScanResult(env, id, input)` | Records the scanner verdict; passing results move to `pending_review`, failing results move to `rejected` |
| `approveSubmission(env, id, apkKey, reviewedBy)` | Marks a submission as `live` |
| `rejectSubmission(env, id, reason, reviewedBy)` | Marks a submission as `rejected` |
| `cancelSubmission(env, id)` | Cancels a developer submission while it is still in `pending_upload` |
| `getSubmissionsDueForAutoApproval(env)` | Returns submissions where `review_after <= now` |
| `getAllLiveApps(env)` | Joins apps with live submissions to build the catalog view |

## D1 binding

The module expects `env.api_control_db` to be bound to a Cloudflare D1 database.

Example `wrangler.jsonc` binding:

```jsonc
{
  "d1_databases": [
    {
      "binding": "api_control_db",
      "database_name": "your-db",
      "database_id": "..."
    }
  ]
}
```
