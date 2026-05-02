# storage.js

`src/store/storage.js`

S3-compatible storage layer for the SafeHaven store. It manages the public app catalog, staging APK uploads, production APK files, and presigned URLs.

The module includes AWS Signature Version 4 signing and has been tested with Hetzner Object Storage. It should also work with other S3-compatible providers.

## Bucket layout

```text
index.json                                  public catalog
apps/{packageName}/{versionCode}/app.apk    production APKs
staging/{packageName}/{versionCode}/app.apk pre-review uploads
```

## Required environment variables

| Var | Description |
|---|---|
| `SH_S3_ENDPOINT` | Full endpoint URL, for example `https://nbg1.your-provider.com` |
| `SH_S3_BUCKET` | Bucket name |
| `SH_S3_REGION` | Region identifier, defaults to `nbg1` |
| `SH_S3_ACCESS_KEY` | S3 access key |
| `SH_S3_SECRET_KEY` | S3 secret key |

## Index functions

| Function | Purpose |
|---|---|
| `getIndex(env)` | Fetches and parses `index.json`; returns an empty index if it does not exist |
| `putIndex(env, index)` | Serialises and writes `index.json` |
| `addOrUpdateApp(env, appEntry)` | Adds or updates an app entry in the catalog |
| `addVersionToApp(env, packageName, versionEntry)` | Adds or updates a version on an existing app entry |
| `removeApp(env, packageName)` | Removes an app and all versions from the catalog |
| `removeVersionFromApp(env, packageName, versionCode)` | Removes one app version from the catalog |

## APK functions

| Function | Purpose |
|---|---|
| `copyToProduction(env, packageName, versionCode)` | Copies an APK from staging to the production key |
| `deleteStagingApk(env, packageName, versionCode)` | Deletes the staging APK after promotion |
| `deleteApk(env, packageName, versionCode)` | Deletes a production APK |
| `headStagingObject(env, packageName, versionCode)` | Checks that a staging APK exists and returns its size |

## Presigned URL functions

| Function | Purpose |
|---|---|
| `getPresignedUploadUrl(env, packageName, versionCode, expiresIn)` | Returns a presigned PUT URL for direct production upload |
| `getPresignedStagingUploadUrl(env, packageName, versionCode, expiresIn)` | Returns a presigned PUT URL for the normal staging upload flow |
| `getPresignedDownloadUrl(env, key, expiresIn)` | Returns a presigned GET URL for any object key, used by the scanner |

The default expiry for presigned URLs is 900 seconds, or 15 minutes.

## Path helpers

| Function | Output |
|---|---|
| `apkKey(packageName, versionCode)` | Production APK object key |
| `stagingKey(packageName, versionCode)` | Staging APK object key |
