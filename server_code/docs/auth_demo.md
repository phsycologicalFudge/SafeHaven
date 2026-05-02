# auth_demo.js

`src/store/auth_demo.js`

Static-token auth adapter for self-hosted demo deployments. It does not require a database or login system.

Use this when running the store by itself through `src/index.demo.js`.

## Token roles

| Role | Env var | Permissions |
|---|---|---|
| Developer | `DEMO_DEV_TOKEN` | Register apps, verify repos, and submit APKs |
| Admin | `DEMO_ADMIN_TOKEN` | Developer permissions, plus approve, reject, suspend, and remove actions |

If the bearer token does not match either env var, `getUser` returns `null` and the request is treated as unauthorized.

## Usage

```js
import { demoAuth } from "./store/auth_demo.js";

return handleStore(request, env, demoAuth);
```

## Required `wrangler.jsonc` vars

```jsonc
{
  "vars": {
    "DEMO_DEV_TOKEN": "your-dev-token-here",
    "DEMO_ADMIN_TOKEN": "your-admin-token-here"
  }
}
```

Generate both values as long random strings.

There is no login flow in the demo adapter. Callers pass the token directly:

```http
Authorization: Bearer <token>
```
