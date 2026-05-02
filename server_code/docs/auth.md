# auth.js

`src/store/auth.js`

Shared auth helpers used by store auth adapters. This file is not an adapter by itself.

## Exports

### `getBearerToken(request)`

Reads the `Authorization` header and extracts a bearer token.

Returns an empty string if the header is missing or malformed.

### `normalizeStoreUser(user)`

Takes a raw user object from any auth source and returns the shape expected by the store:

```js
{
  id: string,
  email: string,
  developerEnabled: boolean,
  admin: boolean
}
```

It accepts both `developerEnabled` and `developer_enabled`, so custom adapters can use either field name.

Returns `null` if the input has no `id`.
