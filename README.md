# SafeHaven

SafeHaven is an Android app store focused on transparency and most importantly, security. 

It is designed for people who want an alternative android app store without the risk of getting malware from uknown sources.

## What this repo contains

- The Android client
- App screens and UI code
- Store/catalog browsing logic
- Shared project files for building the app
- 'server_code', which links to the backend/store server code

## Building the app

Make sure Flutter is installed, then run:

```bash
flutter pub get
flutter run
```

For a release APK:

```bash
flutter build apk --release
```

For an app bundle:

```bash
flutter build appbundle --release
```

## Backend

The backend lives under `server_code` and handles the store API, app submissions, APK scanning flow, S3-compatible storage, and the public catalog.

## Current status

SafeHaven is still early. The client, backend, and review flow may change as the project develops.

## Licence

MIT
