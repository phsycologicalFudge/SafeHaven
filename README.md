# SafeHaven

SafeHaven is an Android app distribution platform focused on transparency and security. Apps are linked to their source repositories, verified against developer ownership, and regularly scanned both before and after being made available.
To get updated on the latest developement news, join the discord! https://discord.gg/VYubQJfcYM


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
