# Running your own SafeHaven store

This guide shows how to run the full SafeHaven store stack. It covers the Cloudflare Worker store API, object storage, D1 setup, and the APK scanner service.

## Requirements

- A Cloudflare account with Workers and D1 enabled
- An S3-compatible object storage bucket, such as Hetzner, Backblaze B2, Cloudflare R2, or AWS S3
- A Linux VPS for the scanner, Ubuntu 24.04 is recommended
- Node.js 18+
- Wrangler installed locally

## 1. Clone and install

```bash
git clone https://github.com/your-org/safehaven.git
cd safehaven/server_code/safehaven_store
npm install
```

## 2. Configure Wrangler

Copy the example config:

```bash
cp wrangler.example.jsonc wrangler.jsonc
```

Edit `wrangler.jsonc` and set the Worker name, entry file, demo tokens, scanner secret, and D1 binding:

```jsonc
{
  "name": "safehaven-store",
  "main": "src/index.demo.js",

  "vars": {
    "DEMO_DEV_TOKEN": "generate-a-random-string",
    "DEMO_ADMIN_TOKEN": "generate-a-different-random-string",
    "SH_SCANNER_SECRET": "generate-another-random-string"
  },

  "d1_databases": [
    {
      "binding": "api_control_db",
      "database_name": "safehaven",
      "database_id": "your-d1-database-id"
    }
  ]
}
```

S3 credentials are added as Wrangler secrets in step 4.

## 3. Create the D1 database

```bash
wrangler d1 create safehaven
```

Copy the `database_id` from the command output into `wrangler.jsonc`, then apply the schema:

```bash
wrangler d1 execute safehaven --local --file=migrations/schema.sql
wrangler d1 execute safehaven --file=migrations/schema.sql
```

The first command applies the schema to your local dev database. The second applies it to the deployed database.

## 4. Set S3 secrets

Run each command separately. Wrangler will ask for the value.

```bash
wrangler secret put SH_S3_ENDPOINT
wrangler secret put SH_S3_BUCKET
wrangler secret put SH_S3_REGION
wrangler secret put SH_S3_ACCESS_KEY
wrangler secret put SH_S3_SECRET_KEY
```

`SH_S3_ENDPOINT` should include the scheme, for example:

```text
https://nbg1.your-provider.com
```

The bucket must already exist. Public read access should stay disabled because the Worker generates presigned URLs for upload and download access.

## 5. Configure bucket CORS

The repo includes a `cors.json` file for direct browser uploads to presigned PUT URLs.

For Hetzner or another S3-compatible provider using the AWS CLI:

```bash
aws s3api put-bucket-cors \
  --bucket your-bucket-name \
  --cors-configuration file://cors.json \
  --endpoint-url https://your-s3-endpoint.com
```

You can also apply the same CORS policy through your storage provider's dashboard if they support it.

## 6. Deploy the Worker

```bash
wrangler deploy
```

## 7. Install the scanner

Copy the scanner files to your VPS:

```bash
scp sub_modules/safehaven/safehaven_scanner.py root@your-server:/root/
scp sub_modules/safehaven/scanner_bootstrap.sh root@your-server:/root/
```

SSH into the VPS and run the bootstrap script:

```bash
ssh root@your-server
bash /root/scanner_bootstrap.sh
```

Edit `/root/.env`:

```env
CS_API_URL="https://your-worker.workers.dev"
VPS_AUTH_SECRET="the-same-value-you-set-for-SH_SCANNER_SECRET"
POLL_INTERVAL="30"
```

Restart the scanner service:

```bash
systemctl restart safehaven-scanner
systemctl status safehaven-scanner
```

## 8. Verify the setup

Check the Worker catalog endpoint:

```bash
curl https://your-worker.workers.dev/store/index.json
```

Check the scanner health endpoint:

```bash
curl http://your-server-ip:8080/health
```

## Token reference

| Token | Where it is set | Access granted |
|---|---|---|
| `DEMO_DEV_TOKEN` | `wrangler.jsonc` vars | Developer API access, including app registration and APK submission |
| `DEMO_ADMIN_TOKEN` | `wrangler.jsonc` vars | Admin access, including approve, reject, and app management actions |
| `SH_SCANNER_SECRET` | Wrangler secret | Scanner service authentication |

Pass tokens on API requests with:

```http
Authorization: Bearer <token>
```

## Custom auth

The demo adapter uses static tokens. That is enough for personal deployments, testing, or small internal teams.

For real user accounts, implement your own auth adapter. See `auth.md` and `auth_demo.md` for the adapter shape and demo implementation.
