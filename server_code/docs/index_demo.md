# index.demo.js

`src/index.demo.js`

Cloudflare Worker entry point for self-hosted demo deployments. Use this file as `main` in `wrangler.jsonc` when running the store without the ColourSwift account system.

## Behaviour

- Runs `runStoreAutoApprovals` in the background on every request with `ctx.waitUntil`
- Promotes submissions automatically after their review window has passed
- Sends every request to `handleStore` with the `demoAuth` adapter

## Usage

Set this in `wrangler.jsonc`:

```jsonc
{
  "main": "src/index.demo.js"
}
```

## Production integration

Do not use this file when adding the store to an existing Worker or private backend.

Import the store handler directly and call it from your own routing layer:

```js
return handleStore(request, env, yourAuthAdapter);
```

Your auth adapter should return the normalised store user shape described in `auth.md`.
