# vaultwarden-render-template — agent notes

## Render env-vars API replaces, does not append

`PUT https://api.render.com/v1/services/{id}/env-vars` **replaces the entire env-var set** with the array you send — it does not merge with existing vars. Sending only one var wipes all the others, and the next deploy fails (no DB, no RSA keys, etc.).

Always send the **full** env-var set in one PUT, not just the new/changed key.

```powershell
$body = '[
  {"key":"DOMAIN","value":"https://vaultwardenn.onrender.com"},
  {"key":"DATABASE_URL","value":"..."},
  {"key":"SIGNING_KEY","value":"..."},
  {"key":"VW_RSA_KEY","value":"..."},
  {"key":"VW_RSA_PUB_KEY","value":"..."}
]'
Invoke-RestMethod -Uri "https://api.render.com/v1/services/$srvId/env-vars" `
  -Method Put -Body $body -ContentType "application/json" -Headers $hdr
```

## DOMAIN must be set or sync breaks

Without `DOMAIN`, Vaultwarden's `/api/config` returns `environment.vault/api/identity/notifications = "http://localhost/..."`. The Bitwarden client then tries to hit localhost and sync fails silently from the user's perspective.

Required env vars: `DOMAIN`, `DATABASE_URL`, `SIGNING_KEY`, `VW_RSA_KEY`, `VW_RSA_PUB_KEY`.

## Deploy trigger

POST to `https://api.render.com/v1/services/{id}/deploys` with body `{}` (empty JSON object). An empty body or no body returns "invalid JSON" - must send `{}`.

## Keep-alive 403 is the edge, not the app

cron-job.org pings this service to stop the Render free instance spinning down. On 2026-09-27 22:40 UTC one run reported `Failed (403 Forbidden)`.

That 403 did not come from Vaultwarden. `onrender.com` sits behind Cloudflare (`Server: cloudflare`, `CF-RAY`, `x-render-origin-server: Rocket`) and no route here returns 403: `/`, `/alive`, `/api/config` and a disabled `/admin` all return 200, unknown paths return 404, rate limiting returns 429. A 403 therefore means Render's edge rejected that single request - check again before touching the app:

```powershell
curl.exe -s -o NUL -w "%{http_code}`n" https://vaultwardenn.onrender.com/alive
```

Two things that make the failure look worse than it is:

- `/alive` returns a bare ISO timestamp wrapped in quotes, not `OK`. Judge runs by HTTP status, not by body text.
- cron-job.org sends no further failure emails until a run succeeds, so silence after a failure email means "unknown", not "recovered".