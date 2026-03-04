# CORS policy

The FITFLOW API applies a configurable CORS policy so browser-based clients (e.g. Flutter web, React) can call the API from another origin.

## Configuration

- **Env:** `CORS_ALLOWED_ORIGINS`
- **Format:** Comma-separated list of allowed origins, or `*` to allow any origin.
- **Default:**
  - **Development** (`ENV=development`): `*` (allow all origins) so the Flutter web app and other local frontends work without extra config.
  - **Other envs:** No CORS headers unless you set `CORS_ALLOWED_ORIGINS`.

## Examples

```bash
# Allow all origins (development only in production is discouraged)
CORS_ALLOWED_ORIGINS=*

# Allow specific origins (recommended for production)
CORS_ALLOWED_ORIGINS=https://app.fitflow.example.com,https://fitflow.example.com

# Local dev: Flutter web (Chrome), Vite, etc.
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://127.0.0.1:3000
```

## Headers applied

When CORS is enabled (non-empty config), the API sets:

| Header | Value |
|--------|--------|
| `Access-Control-Allow-Origin` | Request `Origin` if allowed, or `*` when policy is allow-all |
| `Access-Control-Allow-Methods` | `GET, POST, PUT, PATCH, DELETE, OPTIONS` |
| `Access-Control-Allow-Headers` | `Content-Type, Authorization` |
| `Access-Control-Expose-Headers` | `X-Request-Id` (so clients can read the request ID from responses) |
| `Access-Control-Max-Age` | `86400` (24h preflight cache) |

`OPTIONS` requests are answered with `204 No Content` and no further handlers run.

## Security

- In **production**, set `CORS_ALLOWED_ORIGINS` to the exact origins of your web app(s). Avoid `*` unless you intentionally allow any origin.
- Credentials (cookies) are not used by the API (auth is Bearer token in `Authorization`), so `Access-Control-Allow-Credentials` is not set.
